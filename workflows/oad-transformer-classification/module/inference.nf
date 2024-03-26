process INFERENCE {
  publishDir "${params.output}/data", mode: 'copy', overwrite: true, pattern: "${tileID}.tif"

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
  publishDir "${params.output}/data", mode: 'copy', overwrite: true, pattern: "inference.vrt"

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

workflow inference {
  take:
  data_cube
  masks
  model

  main:
  inference_ch = Channel.fromPath(data_cube, type: 'dir')
    | map { it -> [it.toString().tokenize('/')[-1], it] }
    | join(masks, by: 0, failOnDuplicate: true, remainder: false)
    | map { it -> [it[0], it[1].listFiles(), it[2]] }
    | map { it -> [it[0], it[1].findAll { jt -> jt.baseName =~ /SEN2[AB]_BOA/ }, it[2] ] }
    | filter { it -> it[1].size() > 0}
    | combine(Channel.fromPath(model))
    | INFERENCE
    | collect
    | VRT
  
  emit:
  inference_ch
}
