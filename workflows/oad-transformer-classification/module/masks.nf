process BBOX {  
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
  tuple path(inTile), path(datacube)
  
  output:
  path('X*', type: 'dir')
  
  script:
  """
  force-cube -s 10 -n 0 -o . -b "base" -j ${task.cpus} $inTile
  """
}

process BINMASK {
  publishDir "${params.output}/masks/${tileID}", mode: 'copy', overwrite: true, pattern: "mask.tif"

  input:
  path tiledir
  
  output:
  tuple val(tileID), path("mask.tif")
  
  script:
  tileID = tiledir[-1].toString()
  """
  gdalinfo -json ${tiledir}/base.tif > info.json
  XSIZE=\$(cat info.json | jq '.bands[] | .block[]' | head -n 1)
  YSIZE=\$(cat info.json | jq '.bands[] | .block[]' | tail -n 1)

  gdal_calc.py -A ${tiledir}/base.tif --outfile=mask.tif --overwrite \
    --calc="1*logical_and(A>=10,A<20)" --type=Byte --NoDataValue=0 \
    --creation-option="BLOCKYSIZE=\${YSIZE}" --creation-option="BLOCKXSIZE=\${XSIZE}" \
    --creation-option="COMPRESS=LZW" --creation-option="PREDICTOR=2"
  """
}

workflow masking {
  take:
  bounding_box
  worldcover_tiles
  proj_definition

  main:
  bbox_ch = Channel.fromPath(bounding_box)
    | BBOX
    | map { it -> new worldTile(it) }
    | map { it.worldcoverTiles() }
    | collect

  mask_ch = Channel.fromPath(worldcover_tiles)
    | combine(bbox_ch)
    | map { it -> new forceTile(it) }
    | filter { it.filterTile() }
    | map { it[0] }
    | combine(Channel.fromPath(proj_definition))
    | CUBE
    | flatten
    | BINMASK

  emit:
  mask_ch
}
