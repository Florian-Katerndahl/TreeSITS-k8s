process ALIGNED_BBOX {  
  input:
  path AOI
  
  output:
  tuple env(LOWER_LONGITUDE), env(UPPER_LONGITUDE), env(LOWER_LATITUDE), env(UPPER_LATITUDE)
  
  shell:
  '''
  ogrinfo -json -ro !{AOI} ADM_ADM_0 > info.json

  BBOX=$(cat info.json | jq '.layers[] | .geometryFields[] | .extent[]')
  LOWER_LONGITUDE=$(bc <<< "x=$(echo $BBOX | cut -d ' ' -f1)/1;x-(x%3)")
  UPPER_LONGITUDE=$(bc <<< "x=$(echo $BBOX | cut -d ' ' -f3)/1;x-(x%3)")
  LOWER_LATITUDE=$(bc  <<< "x=$(echo $BBOX | cut -d ' ' -f2)/1;x-(x%3)")
  UPPER_LATITUDE=$(bc  <<< "x=$(echo $BBOX | cut -d ' ' -f4)/1;x-(x%3)")
  '''
}

process CUBE {
  label 'force'
  
  input:
  tuple path(inTile), val(esaID), path(datacube)
  
  output:
  path('X*', type: 'dir')
  
  script:
  """
  force-cube -s 10 -n 0 -o . -b "${esaID}" -j ${task.cpus} $inTile
  """
}

process BINMASK {
  input:
  path(tiledir)
  
  output:
  tuple val(tileID), path('*.tif')
  
  script:
  tileID = tiledir[-1].toString()
  """
  ESAID=\$(ls -1 ${tiledir} | xargs -I{} basename -s .tif {})
  gdalinfo -json ${tiledir}/\${ESAID}.tif > info.json
  XSIZE=\$(cat info.json | jq '.bands[] | .block[]' | head -n 1)
  YSIZE=\$(cat info.json | jq '.bands[] | .block[]' | tail -n 1)

  gdal_calc.py -A ${tiledir}/\${ESAID}.tif --outfile=\${ESAID}.tif --overwrite \
    --calc="1*logical_and(A>=10,A<20)" --type=Byte --NoDataValue=0 \
    --creation-option="BLOCKYSIZE=\${YSIZE}" --creation-option="BLOCKXSIZE=\${XSIZE}" \
    --creation-option="COMPRESS=LZW" --creation-option="PREDICTOR=2"
  """
}

process DEDUPLICATION {
  label 'gdal'
  label 'xxs'

  publishDir "${params.output}/masks/${tileID}", mode: 'copy', overwrite: true, pattern: "mask.tif"

  input:
  tuple val(tileID), path(masks)

  output:
  tuple val(tileID), path("mask.tif")

  script:
  if (masks.size() > 1)
    """
    mkdir merged
    gdalinfo -json ${masks[0]} > info.json
    XSIZE=\$(cat info.json | jq '.bands[] | .block[]' | head -n 1)
    YSIZE=\$(cat info.json | jq '.bands[] | .block[]' | tail -n 1)
    gdal_merge.py -ot Byte -a_nodata 0 -co "BLOCKYSIZE=\${YSIZE}" \
      -co "BLOCKXSIZE=\${XSIZE}" -co "COMPRESS=LZW" \
      -co "PREDICTOR=2" ${masks} -o mask.tif
    """
  else
    """
    mkdir merged
    mv ${masks} mask.tif
    """
}

workflow masking {
  take:
  bounding_box
  worldcover_tiles
  proj_definition

  main:
  bbox_ch = Channel.fromPath(bounding_box)
    | ALIGNED_BBOX
    | map { it -> new worldTile(it) }
    | map { it.worldcoverTiles() }
    | collect

  mask_ch = Channel.fromPath(worldcover_tiles)
    | combine(bbox_ch)
    | map { it -> new forceTile(it) }  // forceTile is not a good name. I'm still dealing with worldcover tiles!
    | filter { it.filterTile() }
    | map { [it[0], it.esaID()] }
    | combine(Channel.fromPath(proj_definition))
    | CUBE
    | flatten
    | BINMASK
    | groupTuple
    | DEDUPLICATION

  emit:
  mask_ch
}
