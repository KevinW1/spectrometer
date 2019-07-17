/* 
* For Processing 2.0.3
* By Kevin Whitfield
* 3-9-2014 Got it working
* 7-9-2018 added lots of comments
*/


/*
 * New Signal Chain to implement
 *
 * Capture camera image
 * sRGB to linear
 * Average RGB values
 * Average pixel rows
 * flag clipped pixels
 * Smoothing
 * Dark subtraction
 * peakDetection
 * display
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


// Control vars
boolean run = true;
boolean srgbCorrect = true;
boolean preSmooth = false;
boolean dispPixels = false;
boolean peakDetection = true;
int lineStack = 100;
int smoothKernel = 2;
int filterWidth = 6;
float peakThresh = .004;
int peakSpacing = 6;
String camName = "";

// Calibration vars
float[] calDat  = {
    304.9840099276,             // Y intercept
    0.36253405,                 // C1
    0.0022147265,               // C2
    -0.00000264644385912079,    // C3
    269                         // camera row to read from (adjustable)
};  




// Init
void setup() {
    
    cp5 = new ControlP5(this);
    
    initUI(cp5);        // see UI tab

    loadSettings();     // see settings tab
    setupCam(camName);
}



// Main Loop
void draw() {
    
    if (run) {
        data = getPixels(lineStack, dataColor, data);
        analyze();
    }

    display();  // Display data
    cp5.draw(); // UI draw
}



void analyze() {

    if (preSmooth) {
        buffer1 = convolve(kernels[smoothKernel], data);

    }else{
        buffer1 = data.clone();
    }


    if (peakDetection) {
        buffer2 = smoothDat(2, filterWidth, buffer1);
        findPeaks(buffer1, buffer2, peakThresh, peakSpacing, peaks);  // find peaks
    }
}



void setupCam(String _camName) {
    
    // retrieves list of available cameras
    String[] cameras = Capture.list();      
    int camIndex = 0;

    if (cameras.length == 0) {
        // No cameras available, kick 'em out!
        println("no cameras available, quitting...");
        exit();                             
    }
    else {

        // Add list of cameras to drop down list in UI
        for (int i = 0; i < cameras.length; i++) {
            d2.addItem(cameras[i], i);
        }

        // gets the selected camera by name
        if (Arrays.asList(cameras).contains(_camName)) {
            camIndex = Arrays.asList(cameras).indexOf(_camName);
        }

        // set camera to be used as spectrometer
        cam = new Capture(this, cameras[camIndex]);

        // parse the resolution from the name of the camera
        // might not work with all cameras, but does with the spectrometer
        // required because bufWidth and bufHeight in Capture are protected :(
        String[] res = match(cameras[camIndex], "size=(.*?\\d+)x(.*?\\d+)");

        if (res == null) {
            println("Camera resolution was not found, quitting...");
            exit(); 
        }

        camWidth = int(res[1]);  // set the new x resolution
        camHeight = int(res[2]);  // set the new y resolution
        
        // size arrays to match new input format
        dataColor   = new float[camWidth][3];
        wavelength  =  new float[camWidth];
        data        = new float[camWidth];
        dark        = new float[camWidth];
        buffer2     = new float[camWidth];
        peaks       = new boolean[camWidth];
        pg          = createGraphics(camWidth, camHeight);

        //update wavelength array with cal data
        calibrate(wavelength, calDat);
      
        // start the camera connection
        cam.start();
    }
}



void calibrate(float[] _wavelength, float[] _calDat) {

    /* 
     * _wavelength[] is a translation table.
     * Index indicates pixel position on camera
     * Value at index indicates associated wavelength
     * Coefficients were generated in MS Excel using regression
     */

    for (int i = 0; i < _wavelength.length; i++) {
        _wavelength[i] = _calDat[0] + _calDat[1]*i + _calDat[2]*pow(i, 2) + _calDat[3]*pow(i, 3);
    }
}



void darkCapture() {

    /* 
     * dark[] stores a snapshot of spectral data which is used
     * to null out any bias in the real signal by subtracting
     * this captures that data.  Subtraction is done in getPixels()
     */

    Arrays.fill(dark, 0.0);             // Clear the dark sample array
    data = getPixels(lineStack, dataColor, data);  //capture the new data (dark will be zero)
    arrayCopy(data, dark);                  //set dark[] equal to the new data
}



float[] getPixels(int _halfWidth, float[][] _dataColor, float[] _data ) {

   /*
    * captures pixel data from camera
    * performs line averaging 
    * performs dark subtraction
    * data[] stores averaged monochrome pixel values
    * dataColor[] stores averaged R,G,B pixel values
    */

    float[] output = _data.clone();

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
            output[i] = val;

            // fill RGB data array
            _dataColor[i][0] = R;
            _dataColor[i][1] = G;
            _dataColor[i][2] = B;


        }
    }
    return output;
}



// finds peaks
void findPeaks(float[] _data, float[] _smoothedData, float _thresh, int _width, boolean[] _peaks) {

    // Reset peak array
    Arrays.fill(_peaks, false);

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
