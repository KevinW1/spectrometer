// 1D convolution
float[] convolve(int[] _kernel, float[] _data) {

    // temp arrays used for input/output
    float[] output = _data.clone();

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
                position  *= -1;
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
        output[i] = val;
    }

    return output;
}


// multi-pass boxcar smoothing, used for peak detection in analyze()
float[] smoothDat(int _pass, int _window, float[] _data) {

    // temp arrays used for input/output
    float[] output = _data.clone(); //, data3 = _data.clone();
    
    // set boxcar size based on window size
    int[] kernel = new int[_window*2+1];
    
    // box kernel
    Arrays.fill(kernel, 1);

    // last entry is sum, in this case sum=length-1 because all 1
    kernel[_window*2] = kernel.length-1;

    // pass over data
    for (int k = 0; k < _pass; k++) {
        output = convolve(kernel, output);
        //data2 = data3;  //swap in/out arrays
    }

    return output;
}



// converts a float array to a csv file for fun in MS excel
String[] toCsv(float[] _data, float[] _wavelength, boolean[] _peaks) {

    String[] fileContents=new String[_data.length];

    for (int i = 0; i < _data.length; i++) {
        fileContents[i] = (str(i) + "," +  str(_wavelength[i]) + "," + str(_data[i]) + "," + str(_peaks[i]));
    }

    return fileContents;
}




float srgbToLinear(float pixelValue) {
    
    //https://en.wikipedia.org/wiki/SRGB
   
    if (pixelValue <= 0.04045) {
        return pixelValue/12.92;
    }
    else {
        return pow(((pixelValue + 0.055)/(1 + 0.055)), 2.4);
    }
}


float roundN(float _val, int _place){

    return Math.round(_val * 10 * _place) / 10*_place;

}
