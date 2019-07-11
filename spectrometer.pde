/* 
* For Processing 2.0.3
* By Kevin Whitfield
* 3-9-2014 Got it working
* 7-9-2018 added lots of comments
*/



// Imports
import processing.video.*;
import java.util.Arrays;
import controlP5.*;                                 // only external dependency


// Objects
Capture cam;                                        // camera in spectrometer
ControlP5 cp5;                                      // UI
DisposeHandler dh = new DisposeHandler(this);       // to run stuff on exit
Textlabel cp5Text;                                  // stores label, reused several times
DropdownList d1, d2;                                // d1 = smoothKernel, d2 = camera select


// Primary data 
PGraphics pg;                                       // store camera image for small preview
JSONObject settings = new JSONObject();             // stores settings
int camWidth = 640;                                 // Camera input width
int camHeight = 480;                                // Camera input height
float[][] dataColor;                                // averaged pixel data from line stacking
float[] wavelength, data, dark, buffer1, buffer2;   // data arrays
boolean[] peaks;                                    //peak location


// Smoothing kernels
// last index is the sum of all previous indexes, used for normalization
int[] kernel0 = {-3, 12, 17, 12, -3, 35};
int[] kernel1 = {-2, 3, 6, 7, 6, 3, -2, 21};
int[] kernel2 = {-21, 14, 39, 54, 59, 54, 39, 14, -21, 231};
int[] kernel3 = {5, -30, 75, 131, 75, -30, 5, 231};
int[] kernel4 = {15, -55, 30, 135, 179, 135, 30, -55, 15, 429};
int[][] kernels = {kernel0, kernel1, kernel2, kernel3, kernel4};


// Application settings
int uiWidth = 640;
int uiHeight = 480;
int bgColor = 15;
String imageExt = ".png";
String fileName = "";
boolean saveCSV  = false;
String settingsFile = "settings";


///////////////////////// Control vars
boolean run = false;
boolean srgbCorrect = true;
boolean preSmooth = true;
boolean dispPixels = false;
boolean peakDetection = true;
int lineStack = 20;
int smoothKernel = 2;
int filterWidth = 6;
float peakThresh = .004;
int peakSpacing = 6;
String camName = "name=PS2 EyeToy,size=640x480,fps=5";

///////////////////////// Calibration vars
float[] calDat  = {
    304.9840099276,             // Y intercept
    0.36253405,                 // C1
    0.0022147265,               // C2
    -0.00000264644385912079,    // C3
    269                         // camera row to read from (adjustable)
};  




//////////////////////////////////////////////////////////////////////// Init
void setup() {

    // Window setup
    size(uiWidth, uiHeight);
    colorMode(RGB, 255);
    background(bgColor);
    textAlign(CENTER, CENTER);

    // UI setup
    cp5 = new ControlP5(this);
    cp5.setAutoDraw(false);

    cp5.addToggle("run")
        .setPosition(40, 320)
        .setSize(40, 10)
        .setLabel("Run")
        .captionLabel().setPaddingY(-8).setPaddingX(44);

    cp5.addBang("launchChooser")
        .setPosition(120, 320)
        .setSize(40, 10)
        .setLabel("Load File")
        .captionLabel().setPaddingY(-8).setPaddingX(44);  

    cp5.addBang("darkCapture")
        .setPosition(120, 375)
        .setSize(10, 10)
        .setLabel("Dark Capture")
        .captionLabel().setPaddingY(-8).setPaddingX(14);  

    cp5.addSlider("lineStack")
        .setPosition(40, 360)
        .setSize(100, 10)
        .setRange(0, 200)
        .setLabel("Line Averging");

    cp5.addToggle("srgbCorrect")
        .setPosition(40, 375)
        .setSize(10, 10)
        .setLabel("Linear Color")
        .captionLabel().setPaddingY(-8).setPaddingX(14);

    cp5.addToggle("preSmooth")
        .setPosition(40, 390)
        .setSize(10, 10)
        .setLabel("Smooth")
        .captionLabel().setPaddingY(-8).setPaddingX(14);

    cp5.addToggle("peakDetection")
        .setPosition(310, 395)
        .setSize(10, 10)
        .setLabel("Peak Detection")
        .captionLabel().setPaddingY(-8).setPaddingX(14);

    cp5.addToggle("dispPixels")
        .setPosition(400, 395)
        .setSize(10, 10)
        .setValue(false)
        .setLabel("Pixel Values")
        .captionLabel().setPaddingY(-8).setPaddingX(14);

    cp5.addSlider("peakSpacing")
        .setPosition(310, 410)
        .setSize(100, 10)
        .setRange(1, 20)
        .setLabel("Peak Spacing");

    cp5.addSlider("filterWidth")
        .setPosition(310, 425)
        .setSize(100, 10)
        .setRange(0, 20)
        .setLabel("Filter Width");

    cp5.addSlider("peakThresh")
        .setPosition(310, 440)
        .setSize(100, 10)
        .setRange(0, .04)
        .setDecimalPrecision(4)
        .setLabel("Peak Threshold");

    cp5.addBang("saveData")
        .setPosition(310, 345)
        .setSize(40, 10)
        .setLabel("SAVE")
        .getCaptionLabel().align(ControlP5.CENTER, ControlP5.CENTER);  

    cp5.addTextfield("fileName")
        .setPosition(360, 345)
        .setSize(240, 25)
        .setText("data Name")
        .keepFocus(true)
        .captionLabel().setVisible(false);

    cp5.addToggle("saveCSV")
        .setPosition(310, 360)
        .setSize(10, 10)
        .setLabel("CSV")
        .captionLabel().setPaddingY(-8).setPaddingX(14);

    d1 = cp5.addDropdownList("smoothKernel")
        .setPosition(40, 415)
        .setLabel("Smooth Kernel");

    d1.addItem("5 quadratic/cubic", 0);
    //d1.addItem("7 quadratic/cubic", 1);   // not used because...?  Check this.
    d1.addItem("7 quartic/quintic", 3);
    d1.addItem("9 quartic/quintic", 4);
    d1.addItem("9 quadratic/cubic", 2);

    d2 = cp5.addDropdownList("camName")
        .setPosition(40, 355)
        .setSize(200, 100)
        .setLabel("Camera");

    // program setup
    
    loadSettings();
    setupCam();
    calibrate();
}



//////////////////////////////////////////////////////////////////////// Main Loop
void draw() {
    
    if (run) {
        getPixels(lineStack, dataColor, data);
        analyze();
    }

    display();  // Display data
    cp5.draw(); // UI draw
}


////////////////////////////////////////////////////////////////////////
void analyze() {
  
    if (preSmooth) {
        convolve(kernels[smoothKernel], data, buffer1);
    }
    else {
        buffer1 = data.clone();
    }


    if (peakDetection) {
        buffer2 = smoothDat(2, filterWidth, buffer1);
        findPeaks(buffer1, buffer2, peakThresh, peakSpacing, peaks);  // find peaks
    }
}


////////////////////////////////////////////////////////////////////////
void setupCam() {
    
    println("setting up cam");
    // retrieves list of available cameras
    String[] cameras = Capture.list();      


    if (cameras.length == 0) {
        // No cameras available, kick 'em out!
        exit();                             
    }  
    else {

        // Add list of cameras to drop down list in UI
        for (int i = 0; i < cameras.length; i++) {
            d2.addItem(cameras[i], i);
        }

        int camIndex = 0;

        // gets the selected camera by name
        if (Arrays.asList(cameras).contains(camName)) {
            camIndex = Arrays.asList(cameras).indexOf(camName);
        }

        // set camera to be used as spectrometer
        cam = new Capture(this, cameras[camIndex]);

        // parse the resolution from the name of the camera
        String[] res = match(cameras[camIndex], "size=(.*?\\d+)x(.*?\\d+)");

        if (res != null) {

            camWidth = int(res[1]);  // set the new x resolution
            camHeight = int(res[2]);  // set the new y resolution
            
            // size arrays to match new input format
            dataColor = new float[camWidth][3];
            wavelength =  new float[camWidth];
            data = new float[camWidth];
            dark = new float[camWidth];
            buffer1 = new float[camWidth];
            buffer2 = new float[camWidth];
            peaks = new boolean[camWidth];
            pg = createGraphics(camWidth, camHeight);
        }

        // start the camera connection
        cam.start();
    }
}


////////////////////////////////////////////////////////////////////////
void calibrate() {

    println("calibrate");
    /* 
     * wavelength[] is a translation table.
     * Index indicates pixel position on camera
     * Value at index indicates associated wavelength
     * Coefficients were generated in MS Excel using regression
     */

    for (int i = 0; i < wavelength.length; i++) {
        wavelength[i] = calDat[0] + calDat[1]*i + calDat[2]*pow(i, 2) + calDat[3]*pow(i, 3);
    }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void darkCapture() {

    println("dark capture");
    /* 
     * dark[] stores a snapshot of spectral data which is used
     * to null out any bias in the real signal by subtracting
     * this captures that data.  Subtraction is done in getPixels()
     */

    //clear the dark sample array
    // dark = new float[camWidth]; might be better
    for (int i = 0; i < dark.length; i++) {
        dark[i] = 0;                              
    }

    //capture the new data (dark will be zero)
    getPixels(lineStack, dataColor, data);
    
    //set dark[] equal to the new data
    arrayCopy(data, dark);
}


////////////////////////////////////////////////////////////////////////
void getPixels(int _halfWidth, float[][] _dataColor, float[] _data ) {

   /*
    * captures pixel data from camera
    * performs line averaging 
    * performs dark subtraction
    * data[] stores averaged monochrome pixel values
    * dataColor[] stores averaged R,G,B pixel values
    */

    if (cam.available() == true) {

        // gets new pixel data
        cam.read();
        cam.loadPixels();

        for (int i = 0; i < _data.length; i++) {

            // accumulation buffer
            float R=0, G=0, B=0; 
            color c = 0;

            // does the line averaging
            for (int j = 0; j <= _halfWidth*2; j++) {
                c = cam.pixels[i + (camWidth * (int(calDat[4]) + _halfWidth - j ))];
                R += ((c >> 16) & 0xFF);
                G += ((c >> 8) & 0xFF);
                B += (c & 0xFF);
            }

            // Average the values across the accumulated lines
            R /= (2*_halfWidth)+1;
            B /= (2*_halfWidth)+1;
            G /= (2*_halfWidth)+1;

            // average RGB channels
            // normalize to 0-1
            // apply dark subtraction 
            //clamp negatives
            float val = max( ((R + G + B)/765) - dark[camWidth-i-1], 0 );  

            //convert to linear if requested (assumes sRGB space for camera)
            if (srgbCorrect) {
                val = srgbToLinear(val);
            }

            // fill master data array
            _data[camWidth-i-1] = val;

            // fill RGB data array
            _dataColor[camWidth-i-1][0] = R;
            _dataColor[camWidth-i-1][1] = G;
            _dataColor[camWidth-i-1][2] = B;

            // move to peak function?
            Arrays.fill(peaks, false);
        }
    }
}


////////////////////////////////////////////////////////////////////////
float srgbToLinear(float _data) {
    
    //https://en.wikipedia.org/wiki/SRGB

    float newVal = 0;
    float a = 0.055;
    
    if (_data <= 0.04045) {
        newVal = _data/12.92;
    }
    else {
        newVal = pow(((_data+a)/(1+a)), 2.4);
    }

    return  newVal;
}


////////////////////////////////////////////////////////////////////////

// 1D convolution
void convolve(int[] _kernel, float[] _data, float[] _output) {

    // half the kernel width
    int halfWidth = int((_kernel.length-1)*0.5);

    // last index in kernel array is sum
    float normalization = 1/float(_kernel[_kernel.length-1]);
    
    // iterate through data to be convolved
    for (int i = 0; i < _data.length; i++) {
        
        float val = 0;
        
        // iterate through kernel
        for (int j = 0; j < _kernel.length-1; j++) {
            
            // position in data array
            int position = i-halfWidth+j;
            
            // reflect at zero
            if (position < 0) {
                position  = abs(position);
            }

            // reflect at end
            else if (position >= _data.length) {
                position = position - 2*(position - _data.length+1);
            }
            
            // accumulate
            val += _data[position] * _kernel[j];
        }

        //normalize
        val *= normalization;

        // store output
        _output[i] = val;
    }
}


////////////////////////////////////////////////////////////////////////

// multi-pass boxcar smoothing, used for peak detection in analyze()
float[] smoothDat(int _pass, int _window, float[] _data) {

    // temp arrays used for input/output
    float[] data2 = _data.clone(), data3 = _data.clone();
    
    // set boxcar size based on window size
    int[] kernel = new int[_window*2+1];
    
    // box kernel
    Arrays.fill(kernel, 1);

    // last entry is sum, in this case sum=length-1 because all 1
    kernel[_window*2] = kernel.length-1;

    // pass over data
    for (int k = 0; k < _pass; k++) {
        convolve(kernel, data2, data3);
        data2 = data3;  //swap in/out arrays
    }

    return data2;
}


////////////////////////////////////////////////////////////////////////

// finds peaks
void findPeaks(float[] _data, float[] _smoothedData, float _thresh, int _width, boolean[] _peaks) {

    // iterate over data minus window size (edge clipping, because the specro doesn't go to the edges anyways)
    for (int i = 0+_width; i < _data.length-_width; i++) {
        
        // place to store neighbor values
        float[] leftNeighbors = new float[_width];
        float[] rightNeighbors = new float[_width];

        // get L and R neighbor values
        arrayCopy(_data, i-_width, leftNeighbors, 0, _width);
        arrayCopy(_data, i+1, rightNeighbors, 0, _width);

        // find the maximum values to either side of the data point, within the window
        float leftMax = max(leftNeighbors);
        float rightMax = max(rightNeighbors);

        // if our data point is higher than both
        if (leftMax-_data[i] <0 && rightMax-_data[i] <0) {
            
            // and it's higher than the threshold between the real and smoothed data
            if (_data[i] >= _smoothedData[i]+_thresh) {
                _peaks[i] = true;
            }
            else {
                _peaks[i] = false;
            }
        }
    }
}


////////////////////////////////////////////////////////////////////////

// Main display drawing function
void display() {

    // setup the colors and strokes
    background(bgColor);
    fill(0);
    noStroke();
    rect(0, 50, camWidth, 235);

    // graph vertical scale
    for (int i = 0; i < 100; i++) {
        drawVScale(50, 235, i);
    }

    // horizontal elements
    for (int i = 0; i < camWidth; i++) {

        // plot H scales
        drawHScale(50, 235, i, wavelength); 
        // spectrum bars
        drawSpectrums(10, 5, 25, 15, i);
        // data plot
        drawGraph(50, 235, 255, buffer1, i);

        // peaks and smoothed data
        if (peakDetection) {
          drawGraph(50, 235, color(1, 108, 158, 255), buffer2, i);
          drawPeaks(50, 235, buffer1, peaks, i);
        }

        // warn of clipped pixels
        clipWarning(50, 235, 0.90, data, i);
    }

    // raw camera feed
    videoOverlay(40, 420, .1);
}


////////////////////////////////////////////////////////////////////////

// Draws horizontal bars that show the averaged results from the camera feed
void drawSpectrums(int _y, int _height, int _y2, int _height2, int _i ) {
    noStroke();

    // color bar
    fill(color(dataColor[_i][0], dataColor[_i][1], dataColor[_i][2]));
    rect(_i, _y, 1, _height);

    // b&w bar
    fill(data[_i]*255);
    rect(_i, _y2, 1, _height2);
}

////////////////////////////////////////////////////////////////////////

// makes a line plot
void drawGraph(int _y, int _height, color c, float[] _data, int _i) {

    // current and previous points
    int pos =  int(_height*_data[_i]), pre =  int(_height*_data[_i]);
    
    if (_i != 0) {
      pre =  int(_height*_data[_i-1]);
    }

    stroke(c);
    line(_i, _y+_height-pre, _i+1, _y+_height-pos);
}

////////////////////////////////////////////////////////////////////////

// Draws the horizontal scales
void drawHScale(int _y, int _height, int _i, float[] _wavelength) {
  
    float val = 0;
    String label = "";
    
    // compute label text
    if (dispPixels) {
        val = _i;
        label = str(round(val))+"px";
    }
    else {
        val = _wavelength[_i];
        label = str(round(val))+"nm";
    }

    // decide if to draw label text
    if (0.99 > val%100) {
        stroke(50);
        fill(100);
        line(_i, _y, _i, _y+5+_height); //tick mark

        cp5Text = new Textlabel(cp5, label, _i-12, _y+_height+10);
        cp5Text.setColor(100);
        cp5Text.draw(this);
    }
    // else if (val%10 == 0) {
    //   stroke(20);
    //   line(_i, _y, _i, _y+5+_height);
    // }
}


////////////////////////////////////////////////////////////////////////
// draw vertical scale tick marks
void drawVScale(int _y, int _height, int _i) {

    float yPos = (_height*(100-_i)/100)+_y;
    
    if (_i == 0) {
        stroke(2, 52, 77);
        line(0, yPos, camWidth, yPos);
    }
    else if (_i == 99) {
        stroke(50);
        line(0, _y, camWidth, _y);
    }
    else if (_i%20 == 0 && _i !=0) {
        stroke(20);
        line(0, yPos, camWidth, yPos);

        // percent text
        cp5Text = new Textlabel(cp5, (str(_i)+"%"), 1, int(yPos-10));
        cp5Text.setColor(100);
        cp5Text.draw(this);
    }
}


////////////////////////////////////////////////////////////////////////

void drawPeaks(int _y, int _height, float[] _data, boolean[] _peaks, int _i) {

    int pos =  _y + _height - round(_height * _data[_i]);

    if (_peaks[_i]) {

        stroke(255, 0, 0, 255);
        noFill();
        ellipse(_i+1, pos, 6, 6);
        String label;
        
        if (dispPixels) {
            label = str(_i);  //peak data for calibration
        }
        else {
            label = str(round(wavelength[_i]));
        }

        cp5Text = new Textlabel(cp5, label, _i+3, pos-4);
        cp5Text.setColor(255);
        cp5Text.draw(this);
    }
}


////////////////////////////////////////////////////////////////////////
// draws vertical bars over any part of the graph that has clipped
void clipWarning(int _y, int _height, float _thresh, float[] _data, int _i) {

    if (_data[_i] >= _thresh ) {
        stroke(255,0,0);
        line(_i, _y, _i, _y + _height);
    }

}


////////////////////////////////////////////////////////////////////////
// draws the raw feed form the camera and the area being sampled
void videoOverlay(int _x, int _y, float _scale) {

  pg.beginDraw();
  // draw camera feed
  pg.set(0, 0, cam);

  // draw the region being sampled
  pg.noStroke();
  pg.fill(0, 255, 255, 100);
  pg.rect(0, calDat[4]-lineStack, pg.width, lineStack*2+1);
  pg.stroke(0, 255, 255, 255);
  pg.line(0, calDat[4], pg.width, calDat[4]);

  pg.endDraw();

  // place image on screen
  image(pg, _x, _y, pg.width*_scale, pg.height*_scale);
  stroke(2, 52, 77);
  noFill();
  rect(_x, _y, pg.width*_scale, pg.height*_scale);  //border
}


////////////////////////////////////////////////////////////////////////
// listen for the space-bar and save data
void keyPressed() {

    if (keyCode == 32 || keyCode == ENTER || keyCode == RETURN) {
        saveData();
    }

}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// called every button press
void controlEvent(ControlEvent theEvent) {
    
    // update drop down lists on selection
    if (theEvent.isGroup()) {
        
        int myIndex = int(theEvent.getGroup().getValue());
        String myName = theEvent.getGroup().getName();
        
        if (myName == "smoothKernel") {
            smoothKernel = myIndex;
        }
        else if (myName == "camName") {
            ListBoxItem selectedItem = d2.getItem((int)theEvent.value());
            camName = selectedItem.getName();
            cam.stop();
            setupCam();
        }
    }
}


////////////////////////////////////////////////////////////////////////

// converts the main data array to a csv file for fun in MS excel
String[] toCsv(float[] _data) {

    String[] fileContents=new String[_data.length];

    for (int i = 0; i < _data.length; i++) {
        fileContents[i] = (str(i) + "," +  str(wavelength[i]) + "," + str(_data[i]) + "," + str(peaks)[i]);
    }

    return fileContents;
}


////////////////////////////////////////////////////////////////////////

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


////////////////////////////////////////////////////////////////////////

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


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
  
        //cam.stop();
        //setupCam();

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
    calData.setJSONArray("darkSamples", darkSamples);
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


////////////////////////////////////////////////////////////////////////

// used to save settings on application quit
public class DisposeHandler {

    DisposeHandler(PApplet pa)
    {
        pa.registerMethod("dispose", this);
    }

    public void dispose()
    {     
        saveSettings();
        println("Quitting");
    }
}
