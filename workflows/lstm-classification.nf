// TODO convert structure to the one proposed by transformer workflow
include { BBOX; CUBE; BINMASK } from './nf-scripts/masks.nf'
include { INFERENCE; VRT } from './nf-scripts/inference.nf'

def worldcoverTiles = { inarr ->
    def locationIDs = [];
    int minLatitude = inarr[2] as int;
    int maxLatitude = inarr[3] as int;
    int minLongitude = inarr[0] as int;
    int maxLongitude = inarr[1] as int;

    for (int latitude = minLatitude; latitude < maxLatitude; latitude+=3) {
        for (int longitude = minLongitude; longitude < maxLongitude; longitude += 3) {
            String latstr = latitude < 0 ? 'S' : 'N';
            String lonstr = longitude < 0 ? 'W' : 'E';

            locationIDs.add("${latstr}${latitude.toString().padLeft(2, '0')}${lonstr}${longitude.toString().padLeft(3, '0')}");
        }
    }
    return locationIDs;
}

def filterTile = { inarr ->
    /* starting with 1 is correct as first array element is file path while all following 
     * are ESA worldcover extends to check against.
     */
    for (i in 1..inarr.size() - 1) {
        if (inarr[0].baseName.contains(inarr[i]))
            return true;
    }
    return false;
}

workflow {
    bbox_ch = Channel.fromPath(params.input_bb)
        | BBOX
        | map { worldcoverTiles(it) }
        | collect

    mask_ch = Channel.fromPath(params.input_wc)
        | combine(bbox_ch)
        | filter { filterTile(it) }
        | map { it[0] }
        | combine(Channel.fromPath(params.input_proj))
        | CUBE
        | flatten
        | BINMASK

    inference_ch = Channel.fromPath(params.input_cube, type: 'dir')
        | map { it -> [it.toString().tokenize('/')[-1], it] }
        | join(mask_ch, by: 0, failOnDuplicate: true, remainder: false)
        | map { it -> [it[0], it[1].listFiles(), it[2]] }
        | map { it -> [it[0], it[1].findAll { jt -> jt.baseName =~ /SEN2[AB]_BOA/ }, it[2] ] }
        | filter { it -> it[1].size() > 0}
        | combine(Channel.fromPath(params.model))

    inference_ch
        | INFERENCE
        | collect
        | VRT
}
