class worldTile {
    ArrayList inarr;

    worldTile(ArrayList inarr) {
        this.inarr = inarr;
    }
    
    ArrayList worldcoverTiles() {
        def locationIDs  = [];
        int minLatitude  = this.inarr[2] as int;
        int maxLatitude  = this.inarr[3] as int;
        int minLongitude = this.inarr[0] as int;
        int maxLongitude = this.inarr[1] as int;

        for (int latitude = minLatitude; latitude <= maxLatitude; latitude+=3) {
            for (int longitude = minLongitude; longitude <= maxLongitude; longitude += 3) {
                String latstr = latitude < 0 ? 'S' : 'N';
                String lonstr = longitude < 0 ? 'W' : 'E';

                locationIDs.add("${latstr}${latitude.toString().padLeft(2, '0')}${lonstr}${longitude.toString().padLeft(3, '0')}");
            }
        }
        return locationIDs;
    }
}
