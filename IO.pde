
// Loads settings from json file
void loadSettings() {

    print("Loading Settings... ");
    
    // check to see if the file is there.
    try {
        settings = loadJSONObject(settingsFile+".json");
    } 
    catch (Exception ex) {
        settings = null;
    }

    // load file
    if (settings != null) {
        JSONObject calData = settings.getJSONObject("calData");
        JSONArray markers = calData.getJSONArray("markers");
        JSONObject controls = settings.getJSONObject("controls");

        // Set Variables
        camName = calData.getString("camName");

        for (int i = 0; i < markers.size(); i++) {
            calDat[i] = markers.getFloat(i);
        }
        imageExt = controls.getString("imageExt");
        peakSpacing = controls.getInt("peakSpacing");
        filterWidth = controls.getInt("filterWidth");
        lineStack = controls.getInt("lineStack");
        smoothKernel  = controls.getInt("smoothKernel");
        peakThresh = controls.getFloat("peakThresh");
        preSmooth = controls.getBoolean("preSmooth");
        srgbCorrect = controls.getBoolean("srgbCorrect");
        peakDetection = controls.getBoolean("peakDetection");
        saveCSV = controls.getBoolean("saveCSV");

        println("Done");
    } 
    else {
        println("Skipping");
        settings = new JSONObject();  //clean it up by re-initalizing it.
    }
}


////////////////////////////////////////////////////////////////////////

// save settings to a json file
void saveSettings() {
    print("Saving Settings... ");

    JSONObject calData = new JSONObject();
    JSONArray markers = new JSONArray();
    JSONArray darkSamples = new JSONArray();
    JSONObject controls = new JSONObject();

    // Cal data 
    for (int i = 0; i < calDat.length; i++) {
        markers.setFloat(i, calDat[i]);
    }

    calData.setString("camName", camName);
    calData.setJSONArray("markers", markers);
    settings.setJSONObject("calData", calData);

    // regular settings
    controls.setString("imageExt", imageExt );
    controls.setInt("peakSpacing", peakSpacing);
    controls.setInt("filterWidth", filterWidth);
    controls.setInt("lineStack", lineStack);
    controls.setInt("smoothKernel", smoothKernel);
    controls.setInt("camWidth", camWidth);
    controls.setInt("camHeight", camHeight);
    controls.setFloat("peakThresh", peakThresh);
    controls.setBoolean("preSmooth", preSmooth);
    controls.setBoolean("srgbCorrect", srgbCorrect);
    controls.setBoolean("peakDetection", peakDetection);
    controls.setBoolean("saveCSV", saveCSV);
    settings.setJSONObject("controls", controls);

    saveJSONObject(settings, settingsFile+".json");
    println("Done");
}


// load a previously saved csv file for display
void loadCsv(String _path) {
    
    run = false;
    cp5.controller("run").setValue(0);
    Table csvTable = loadTable(_path);
    
    for (int i = 0; i < csvTable.getRowCount(); i++) {
        wavelength[i] = csvTable.getFloat(i, 1);
        data[i] = csvTable.getFloat(i, 2);
    }

    analyze();
}

// write data to disk
void saveData() {

    // save image file
    fill(255);
    fileName = cp5.get(Textfield.class, "fileName").getText();
    textAlign(CENTER, CENTER);
    text(fileName+imageExt, width/2, height-20);
    save(fileName+imageExt);
    print ("saving image");

    // save csv file
    if (saveCSV) {
        saveStrings(fileName+".csv", toCsv(data));
        print (" ...and csv file");
    }

}

