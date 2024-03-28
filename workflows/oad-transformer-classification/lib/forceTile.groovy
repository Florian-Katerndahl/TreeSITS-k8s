class forceTile {
    LinkedList inarr;
    String esaID;

    forceTile(LinkedList inarr) {
        this.inarr = inarr;
    }

    // TODO this is not nice
    Boolean filterTile() {
    /* starting with 1 is correct as first array element is file path while all following 
     * are ESA worldcover extends to check against.
     */
        for (i in 1..this.inarr.size() - 1) {
            if (this.inarr[0].baseName.contains(this.inarr[i])) {
                this.esaID = this.inarr[i] as String;
                return true;
            }
        }
        return false;
    }

    def getAt(int index) {
        return this.inarr[index];
    }

    String esaID() {
        return this.esaID;
    }
}
