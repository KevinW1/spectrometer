// UI setup
void initUI(ControlP5 cp5){
    
    // window setup
    size(uiWidth, uiHeight);
    colorMode(RGB, 255);
    background(bgColor);
    textAlign(CENTER, CENTER);
    
    // user controls
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
        .setTriggerEvent(Bang.RELEASE)
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
}



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
        clipWarning(50, 235, 0.90, buffer1, i);
    }

    // raw camera feed
    //videoOverlay(40, 420, .1);
}


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
    // the below craziness is because val can be 449.8 and then 450.1
    // so a threshold is used.  I'm sure there's a better way
    if ((val) % 50 <= .5 ) {
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


// draws vertical bars over any part of the graph that has clipped
void clipWarning(int _y, int _height, float _thresh, float[] _data, int _i) {

    if (_data[_i] >= _thresh ) {
        stroke(255,0,0);
        line(_i, _y, _i, _y + _height);
    }

}


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



// listen for the space-bar and save data
void keyPressed() {

    if (keyCode == 32 || keyCode == ENTER || keyCode == RETURN) {
        saveData(cp5.get(Textfield.class, "fileName").getText(), 
                    saveCSV, 
                    data, 
                    wavelength, 
                    peaks);
    }

}



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
            setupCam(camName);
        }
    }else{

        String myName = theEvent.getController().getName();

        if (myName == "saveData") {
            saveData(cp5.get(Textfield.class, "fileName").getText(), 
                        saveCSV, 
                        data, 
                        wavelength, 
                        peaks);
        }
    }
}





