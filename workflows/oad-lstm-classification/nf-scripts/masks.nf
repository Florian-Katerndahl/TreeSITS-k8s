nextflow.enable.dsl=2

process BBOX {
  cpus 1
  container 'floriankaterndahl/cpu-inference:0.0.1'
  
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
  cpus 2
  container 'davidfrantz/force:latest'

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
  cpus 1
  container 'floriankaterndahl/cpu-inference:0.0.1'
  publishDir "Eolab/masks/${tileID}", mode: 'copy', overwrite: true, pattern: "mask.tif"

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
  
}
