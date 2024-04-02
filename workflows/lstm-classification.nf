// TODO make the difference between lstm and transformer a profile in the config? would be easier since the only differnces are in the config and not the actual workflow

include { masking }   from './module/masks.nf'
include { inference } from './module/inference.nf'

workflow {
    masks = masking(params.input_bb, params.input_wc, params.input_proj)

    inference(params.input_cube, masks, params.model)
}
