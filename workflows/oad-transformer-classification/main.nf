include { masking }   from './module/masks.nf'
include { inference } from './module/inference.nf'

workflow {
    masks = masking(params.input_bb, params.input_wc, params.input_proj)

    inference(params.input_cube, masks, params.model)
}
