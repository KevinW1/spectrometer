//For Processing 2.0.3
//By Kevin Whitfield
//3-9-2014

///////////////////////// Imports
import processing.video.*;
import java.util.Arrays;
import controlP5.*;

///////////////////////// Objects
Capture cam;
ControlP5 cp5;
DisposeHandler dh = new DisposeHandler(this); //to run stuff on exit
Textlabel cp5Text;
DropdownList d1, d2;

///////////////////////// Primary data Objects
PGraphics pg;
JSONObject settings = new JSONObject();


///////////////////////// Primary data arrays
int camWidth = 640;
int camHeight = 480;
float[][] dataColor;
float[] wavelength, data, dark, buffer1, buffer2;
boolean[] peaks;

///////////////////////// Secondary data arrays
int[] kernel0 = {  
  -3, 12, 17, 12, -3, 35
};
int[] kernel1 = {  
  -2, 3, 6, 7, 6, 3, -2, 21
};
int[] kernel2 = {  
  -21, 14, 39, 54, 59, 54, 39, 14, -21, 231
};
int[] kernel3 = {  
  5, -30, 75, 131, 75, -30, 5, 231
};
int[] kernel4 = {  
  15, -55, 30, 135, 179, 135, 30, -55, 15, 429
};
int[][] kernels = {  
  kernel0, kernel1, kernel2, kernel3, kernel4
};

///////////////////////// Application settings
int screenWidth = 640;
int screenHeight = 480;
int bgColor = 15;
String imageExt = ".png";
String fileName = "";
boolean saveCSV  = false;
String settingsFile = "settings";


///////////////////////// Control vars
boolean run = true;
boolean srgbCorrect = true;
boolean preSmooth = true;
boolean dispPixels = false;
boolean peakDetection = true;
int lineStack = 20;
int smoothKernel = 2;
int filterWidth = 6;
float peakThresh = .004;
int peakSpacing = 6;

///////////////////////// Calibration vars
String camName = "name=PS2 EyeToy,size=640x480,fps=5";
float[] calDat  = {  
  304.9840099276, 0.36253405, 0.0022147265, -0.00000264644385912079, 269
};  
//intercept, C1, C2, C3, camRow


////////////////////////////////////////////////////////////////////////
void setup() {
  size(screenWidth, screenHeight);
  colorMode(RGB, 255);
  background(bgColor);
  textAlign(CENTER, CENTER);
  cp5 = new ControlP5(this);
  cp5.setAutoDraw(false);


  cp5.addToggle("run")
    .setPosition(40, 320)
      .setSize(40, 10)
        .setLabel("Run")
          .captionLabel().setPaddingY(-8).setPaddingX(44)
            ;

  cp5.addBang("launchChooser")
    .setPosition(120, 320)
      .setSize(40, 10)
        .setLabel("Load File")
          .captionLabel().setPaddingY(-8).setPaddingX(44)
            ;  

  cp5.addBang("darkCapture")
    .setPosition(120, 375)
      .setSize(10, 10)
        .setLabel("Dark Capture")
          .captionLabel().setPaddingY(-8).setPaddingX(14)
            ;  


  cp5.addSlider("lineStack")
    .setPosition(40, 360)
      .setSize(100, 10)
        .setRange(0, 50)
          .setLabel("Line Averging")
            ;

  cp5.addToggle("srgbCorrect")
    .setPosition(40, 375)
      .setSize(10, 10)
        .setLabel("Linear Color")
          .captionLabel().setPaddingY(-8).setPaddingX(14)
            ;

  cp5.addToggle("preSmooth")
    .setPosition(40, 390)
      .setSize(10, 10)
        .setLabel("Smooth")
          .captionLabel().setPaddingY(-8).setPaddingX(14)
            ;

  cp5.addToggle("peakDetection")
    .setPosition(310, 395)
      .setSize(10, 10)
        .setLabel("Peak Detection")
          .captionLabel().setPaddingY(-8).setPaddingX(14)
            ;

  cp5.addToggle("dispPixels")
    .setPosition(400, 395)
      .setSize(10, 10)
        .setValue(false)
          .setLabel("Pixel Values")
            .captionLabel().setPaddingY(-8).setPaddingX(14)
              ;

  cp5.addSlider("peakSpacing")
    .setPosition(310, 410)
      .setSize(100, 10)
        .setRange(1, 20)
          .setLabel("Peak Spacing")
            ;

  cp5.addSlider("filterWidth")
    .setPosition(310, 425)
      .setSize(100, 10)
        .setRange(0, 20)
          .setLabel("Filter Width")
            ;

  cp5.addSlider("peakThresh")
    .setPosition(310, 440)
      .setSize(100, 10)
        .setRange(0, .04)
          .setDecimalPrecision(4)
            .setLabel("Peak Threshold")
              ;

  cp5.addBang("saveData")
    .setPosition(310, 345)
      .setSize(40, 10)
        .setLabel("SAVE")
          .getCaptionLabel().align(ControlP5.CENTER, ControlP5.CENTER)
            ;  

  cp5.addTextfield("fileName")
    .setPosition(360, 345)
      .setSize(240, 25)
        .setText("data Name")
          .keepFocus(true)
            .captionLabel().setVisible(false)
              ;

  cp5.addToggle("saveCSV")
    .setPosition(310, 360)
      .setSize(10, 10)
        .setLabel("CSV")
          .captionLabel().setPaddingY(-8).setPaddingX(14)
            ;

  d1 = cp5.addDropdownList("smoothKernel")
    .setPosition(40, 415)
      .setLabel("Smooth Kernel")
        ;
  d1.addItem("5 quadratic/cubic", 0);
  //d1.addItem("7 quadratic/cubic", 1);
  d1.addItem("7 quartic/quintic", 3);
  d1.addItem("9 quartic/quintic", 4);
  d1.addItem("9 quadratic/cubic", 2);


  d2 = cp5.addDropdownList("camName")
    .setPosition(40, 355)
      .setSize(200, 100)
        .setLabel("Camera")
          ;


  setupCam();
  loadSettings();
  calibrate();
}


////////////////////////////////////////////////////////////////////////
void draw() {
  if (run) {
    getPixels(lineStack, dataColor, data);
    analyze();
  }
  display();
  cp5.draw();
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
    findPeaks(buffer1, buffer2, peakThresh, peakSpacing, peaks);  //find peaks
  }
}


////////////////////////////////////////////////////////////////////////
void setupCam() {
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    exit();  //No cameras available
  }  
  else {
    for (int i = 0; i < cameras.length; i++) {
      d2.addItem(cameras[i], i);
    }
    int camIndex = 0;
    if (Arrays.asList(cameras).contains(camName)) {
      camIndex = Arrays.asList(cameras).indexOf(camName);
    }
    cam = new Capture(this, cameras[camIndex]);
    String[] res = match(cameras[camIndex], "size=(.*?\\d+)x(.*?\\d+)");
    if (res != null) {
      camWidth = int(res[1]);  //set the new x resolution
      camHeight = int(res[2]);  //set the new y resolution
      //re-size arrays
      dataColor = new float[camWidth][3];
      wavelength =  new float[camWidth];
      data = new float[camWidth];
      dark = new float[camWidth];
      buffer1 = new float[camWidth];
      buffer2 = new float[camWidth];
      peaks = new boolean[camWidth];
      pg = createGraphics(camWidth, camHeight);
    }
    cam.start();
  }
}


////////////////////////////////////////////////////////////////////////
void calibrate() {
  for (int i = 0; i < wavelength.length; i++) {
    wavelength[i] = calDat[0] + calDat[1]*i + calDat[2]*pow(i, 2) + calDat[3]*pow(i, 3);
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void darkCapture() {
  for (int i = 0; i < dark.length; i++) {
    dark[i] = 0;                              //clear the dark sample array
  }
  getPixels(lineStack, dataColor, data);      //capture the new data
  arrayCopy(data, dark);                   //set it equal to the data
}


////////////////////////////////////////////////////////////////////////
void getPixels(int _halfWidth, float[][] _dataColor, float[] _data ) {
  if (cam.available() == true) {
    cam.read();
    cam.loadPixels();  //loadPixels();
    for (int i = 0; i < _data.length; i++) {
      float R=0, G=0, B=0; 
      color c = 0;
      for (int j = 0; j <= _halfWidth*2; j++) {
        c = cam.pixels[i+(camWidth*(int(calDat[4])+_halfWidth-j))];
        //Don't mess this up or your will be forever lost
        R += ((c >> 16) & 0xFF);
        G += ((c >> 8) & 0xFF);
        B += (c & 0xFF);
      }
      R /= (2*_halfWidth)+1;
      B /= (2*_halfWidth)+1;
      G /= (2*_halfWidth)+1;
      float val = max( ((R + G + B)/765) - dark[camWidth-i-1], 0 );  //add 8-bit channels, dark subtraction, negative clamping
      if (srgbCorrect) {
        val = srgbToLinear(val);
      }
      _data[camWidth-i-1] = val;
      _dataColor[camWidth-i-1][0] = R;
      _dataColor[camWidth-i-1][1] = G;
      _dataColor[camWidth-i-1][2] = B;
      Arrays.fill(peaks, false);
    }
  }
}


////////////////////////////////////////////////////////////////////////
float srgbToLinear(float _data) {
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
void convolve(int[] _kernel, float[] _data, float[] _output) {
  int halfWidth = int((_kernel.length-1)*0.5);
  float normalization = 1/float(_kernel[_kernel.length-1]);
  for (int i = 0; i < _data.length; i++) {
    float val = 0;
    for (int j = 0; j < _kernel.length-1; j++) {
      int position = i-halfWidth+j;
      if (position < 0) {
        position  = abs(position);
      }
      else if (position >= _data.length) {
        position =position - 2*(position - _data.length+1);
      }
      val += _data[position] * _kernel[j];
    }
    val *= normalization;
    _output[i] = val;
  }
}


////////////////////////////////////////////////////////////////////////
float[] smoothDat(int _pass, int _window, float[] _data) {
  float[] data2 = _data.clone(), data3 = _data.clone();
  int[] kernel = new int[_window*2+1];
  Arrays.fill(kernel, 1);
  kernel[_window*2] = kernel.length-1;

  for (int k = 0; k < _pass; k++) {
    convolve(kernel, data2, data3);
    data2 = data3;
  }
  return data2;
}


////////////////////////////////////////////////////////////////////////
void findPeaks(float[] _data, float[] _buffer, float _thresh, int _width, boolean[] _peaks) {

  for (int i = 0+_width; i < _data.length-_width; i++) {
    float[] leftNeighbors = new float[_width];
    float[] rightNeighbors = new float[_width];
    arrayCopy(_data, i-_width, leftNeighbors, 0, _width);
    arrayCopy(_data, i+1, rightNeighbors, 0, _width);
    float leftMax = max(leftNeighbors);
    float rightMax = max(rightNeighbors);

    if (leftMax-_data[i] <0 && rightMax-_data[i] <0) {
      if (_data[i] >= _buffer[i]+_thresh) {
        _peaks[i] = true;
      }
      else {
        _peaks[i] = false;
      }
    }
  }
}


////////////////////////////////////////////////////////////////////////
void display() {
  background(bgColor);
  fill(0);
  noStroke();
  rect(0, 50, camWidth, 235);

  for (int i = 0; i < 100; i++) {
    drawVScale(50, 235, i);
  }

  for (int i = 0; i < camWidth; i++) {
    drawHScale(50, 235, i, wavelength); 
    drawSpectrums(10, 5, 25, 15, i);
    drawGraph(50, 235, 255, buffer1, i);
    if (peakDetection) {
      drawGraph(50, 235, color(1, 108, 158, 255), buffer2, i);
      drawPeaks(50, 235, buffer1, peaks, i);
    }
    clipWarning(50, 235, 0.90, data, i);
  }

  videoOverlay(40, 420, .1);
}


////////////////////////////////////////////////////////////////////////
void drawSpectrums(int _y, int _height, int _y2, int _height2, int _i ) {
  noStroke();
  fill(color(dataColor[_i][0], dataColor[_i][1], dataColor[_i][2]));
  rect(_i, _y, 1, _height);
  fill(data[_i]*255);
  rect(_i, _y2, 1, _height2);
}

////////////////////////////////////////////////////////////////////////
void drawGraph(int _y, int _height, color c, float[] _data, int _i) {
  int pos =  int(_height*_data[_i]), pre =  int(_height*_data[_i]);
  if (_i != 0) {
    pre =  int(_height*_data[_i-1]);
  }
  stroke(c);
  line(_i, _y+_height-pre, _i+1, _y+_height-pos);
}

////////////////////////////////////////////////////////////////////////
void drawHScale(int _y, int _height, int _i, float[] _wavelength) {
  float val = 0;
  String label = "";
  if (dispPixels) {
    val = _i;
    label = str(round(val))+"px";
  }
  else {
    val = _wavelength[_i];
    label = str(round(val))+"nm";
  }
  if (0.99 > val%100) {
    stroke(50);
    fill(100);
    line(_i, _y, _i, _y+5+_height);

    cp5Text = new Textlabel(cp5, label, _i-12, _y+_height+10);
    cp5Text.setColor(100);
    cp5Text.draw(this);
  }
  //    else if (val%10 == 0) {
  //      stroke(20);
  //      line(_i, _y, _i, _y+5+_height);
  //    }
}


////////////////////////////////////////////////////////////////////////
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
    cp5Text = new Textlabel(cp5, (str(_i)+"%"), 1, int(yPos-10));
    cp5Text.setColor(100);
    cp5Text.draw(this);
  }
}


////////////////////////////////////////////////////////////////////////
void drawPeaks(int _y, int _height, float[] _data, boolean[] _peaks, int _i) {
  int pos =  _y+_height-round(_height*_data[_i]);
  if (_peaks[_i]) {
    stroke(255, 0, 0, 255);
    noFill();
    ellipse(_i+1, pos, 6, 6);
    String label;
    if (dispPixels) {
      label = str(_i);  //for calibration
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
void clipWarning(int _y, int _height, float _thresh, float[] _data, int _i) {
  if (_data[_i] >= _thresh ) {
    stroke(255);
    line(_i, _y, _i, _y+_height);
  }
}


////////////////////////////////////////////////////////////////////////
void videoOverlay(int _x, int _y, float _scale) {
  pg.beginDraw();
  pg.set(0, 0, cam);
  pg.noStroke();
  pg.fill(0, 255, 255, 100);
  pg.rect(0, calDat[4]-lineStack, pg.width, lineStack*2+1);
  pg.stroke(0, 255, 255, 255);
  pg.line(0, calDat[4], pg.width, calDat[4]);
  pg.endDraw();
  image(pg, _x, _y, pg.width*_scale, pg.height*_scale);
  stroke(2, 52, 77);
  noFill();
  rect(_x, _y, pg.width*_scale, pg.height*_scale);
}


////////////////////////////////////////////////////////////////////////
void keyPressed() {
  if (keyCode == 32 || keyCode == ENTER || keyCode == RETURN) {
    saveData();
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void controlEvent(ControlEvent theEvent) {
  // called every button press
  if (!run) {
    analyze();
    display();
  }
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
String[] toCsv(float[] _data) {
  String[] fileContents=new String[_data.length];
  for (int i = 0; i < _data.length; i++) {
    fileContents[i] = (str(i) + "," +  str(wavelength[i]) + "," + str(_data[i]) + "," + str(peaks)[i]);
  }
  return fileContents;
}


////////////////////////////////////////////////////////////////////////
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
void saveData() {
  fill(255);
  fileName = cp5.get(Textfield.class, "fileName").getText();
  textAlign(CENTER, CENTER);
  text(fileName+imageExt, width/2, height-20);
  save(fileName+imageExt);
  print ("saving image");
  if (saveCSV) {
    saveStrings(fileName+".csv", toCsv(data));
    print (" ...and csv file");
  }
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
void loadSettings() {
  print("Loading Settings... ");
  //////////////////////////////////////////////////// Load objects
  try {
    settings = loadJSONObject(settingsFile+".json");
  } 
  catch (Exception ex) {
    settings = null;
  }
  if (settings != null) {
    JSONObject calData = settings.getJSONObject("calData");
    JSONArray markers = calData.getJSONArray("markers");
    JSONArray darkSamples = calData.getJSONArray("darkSamples");
    JSONObject controls = settings.getJSONObject("controls");

    //////////////////////////////////////////////////// Set Variables
    camName = calData.getString("camName");

    for (int i = 0; i < markers.size(); i++) {
      calDat[i] = markers.getFloat(i);
    }
    for (int i = 0; i < darkSamples.size(); i++) {
      if(i < dark.length){
        dark[i] = darkSamples.getFloat(i);
      }
    }
    imageExt = controls.getString("imageExt");
    peakSpacing = controls.getInt("peakSpacing");
    filterWidth = controls.getInt("filterWidth");
    lineStack = controls.getInt("lineStack");
    smoothKernel  = controls.getInt("smoothKernel");
    peakThresh = controls.getFloat("peakThresh");
    run = controls.getBoolean("run");
    preSmooth = controls.getBoolean("preSmooth");
    srgbCorrect = controls.getBoolean("srgbCorrect");
    peakDetection = controls.getBoolean("peakDetection");
    saveCSV = controls.getBoolean("saveCSV");

    println("Done");
  } 
  else {
    println("Skipping");
    settings = new JSONObject();  //clean it up be re-initalizing it.
  }
}


////////////////////////////////////////////////////////////////////////
void saveSettings() {
  print("Saving Settings... ");

  JSONObject calData = new JSONObject();
  JSONArray markers = new JSONArray();
  JSONArray darkSamples = new JSONArray();
  JSONObject controls = new JSONObject();

  //////////////////////////////////////////////////// Cal data 
  for (int i = 0; i < calDat.length; i++) {
    markers.setFloat(i, calDat[i]);
  }


  //////////////////////////////////////////////////// Dark samples
  for (int i = 0; i < dark.length; i++) {
    darkSamples.setFloat(i, dark[i]);
  }

  calData.setString("camName", camName);
  calData.setJSONArray("markers", markers);
  calData.setJSONArray("darkSamples", darkSamples);
  settings.setJSONObject("calData", calData);

  //////////////////////////////////////////////////// regular settings
  controls.setString("imageExt", imageExt );
  controls.setInt("peakSpacing", peakSpacing);
  controls.setInt("filterWidth", filterWidth);
  controls.setInt("lineStack", lineStack);
  controls.setInt("smoothKernel", smoothKernel);
  controls.setInt("camWidth", camWidth);
  controls.setInt("camHeight", camHeight);
  controls.setFloat("peakThresh", peakThresh);
  controls.setBoolean("run", run);
  controls.setBoolean("preSmooth", preSmooth);
  controls.setBoolean("srgbCorrect", srgbCorrect);
  controls.setBoolean("peakDetection", peakDetection);
  controls.setBoolean("saveCSV", saveCSV);

  settings.setJSONObject("controls", controls);

  saveJSONObject(settings, settingsFile+".json");
  println("Done");
}


////////////////////////////////////////////////////////////////////////
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


////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////

