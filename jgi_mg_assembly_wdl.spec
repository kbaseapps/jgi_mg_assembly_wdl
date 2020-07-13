/*
A KBase module: jgi_mg_assembly_wdl
*/

module jgi_mg_assembly_wdl {
    typedef structure {
        string report_name;
        string report_ref;
    } ReportResults;

    /*
        This example function accepts any number of parameters and returns results in a KBaseReport
    */
    funcdef run_jgi_mg_assembly_wdl(mapping<string,UnspecifiedObject> params) returns (ReportResults output) authentication required;

};
