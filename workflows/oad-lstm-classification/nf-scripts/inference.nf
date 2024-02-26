nextflow.enable.dsl=2

process INFERENCE {
  publishDir "s3://outdir/${k8s.name}/data", mode: 'copy', overwrite: true, pattern: "${tileID}.tif"

  input:
  tuple val(tileID), path(scenes), path(mask), path(model)
  
  output:
  path("${tileID}.tif")
  
  script:
  """
  mkdir ${tileID}
  mv ${scenes} ${tileID}
  echo ${tileID} > tiles.txt
  inference.py --weights ${model} --input-tiles tiles.txt --date-cutoff ${params.cutoff} \
    --mask-dir . --cpus ${task.cpus}
  """
}

process VRT {
  publishDir "s3://outdir/${k8s.name}/data", mode: 'copy', overwrite: true, pattern: "inference.vrt"

  input:
  path(predictions)
  
  output:
  path("inference.vrt")
  
  script:
  """
  find . -type l -name 'X*tif' > vrt_list.txt
  gdalbuildvrt -input_file_list vrt_list.txt inference.vrt
  """
}
