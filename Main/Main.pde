Dot[] dots;

int totalDots = 60;
  
boolean organize;

float prevRotateAngle;
float destRotateAngle;
float rotateAngle;

int changeTime = 120;
int lastFrameChangeTime = 0;

PShader sha;

  
import processing.sound.*;
SoundFile file;
Amplitude amp;

void setup() {
  size(600, 600, P3D); 
  background(0);  
  //frameRate(30);
  ortho(-width / 2, width / 2, -height / 2, height / 2, 0, 1000);
  sphereDetail(5);  
  dots = new Dot[totalDots];
  for(int i=0; i<totalDots; i++){
    dots[i]= new Dot();
    dots[i].setup();
  }
  
  destRotateAngle = 0;
  rotateAngle = 0;

  organize = false;
  
  reloadShader();
  
  file = new SoundFile(this, "sound.wav");
  file.play();
  
  amp = new Amplitude(this);
  amp.input(file);
} 

void reloadShader(){
 sha = loadShader("main.glsl");
 sha.set("resolution", float(width), float(height)); 
}

void draw() {
  boolean tempOrganize = frameCount%(changeTime*2)>changeTime;
  if(organize!=tempOrganize){
    lastFrameChangeTime = frameCount;
    organize = tempOrganize;
    prevRotateAngle = rotateAngle;
    if(organize) destRotateAngle += PI/2;
  }
  
  float easeLerp = easeInOutQuint((float)(frameCount - lastFrameChangeTime) / (float)changeTime);
  rotateAngle = lerp(prevRotateAngle, destRotateAngle, easeLerp);
  
  float[] posX = new float[totalDots];
  float[] posY = new float[totalDots];
  float[] posZ = new float[totalDots];
  float[] sizes = new float[totalDots];
  for(int i=0; i<dots.length; i++){
    dots[i].update(organize);
    
    posX[i] = dots[i].pos.x/(float)width*2;
    posY[i] = dots[i].pos.y/(float)height*2;
    posZ[i] = dots[i].pos.z/(float)width*2;
    sizes[i] = dots[i].sizeSin/(float)200;
  }
    
  sha.set("time", millis() / 1000.0);
  sha.set("mouse", float(mouseX), float(mouseY));
  sha.set("posX", posX);
  sha.set("posY", posY);
  sha.set("posZ", posZ);
  sha.set("size", sizes);
  sha.set("rotate", rotateAngle);
  sha.set("intensity", map(amp.analyze(), 0.0, 0.1, 0.1, 3.0));
  shader(sha);

  fill(255);
  rect(0, 0, width, height);

}

void keyPressed(){
  if(key=='r'){
    reloadShader();
  }else{
    for(int i=0; i<totalDots; i++){
      dots[i].pos.x = 0;
      dots[i].pos.y = 0;
      dots[i].pos.z = 0;
    }
    file.stop();
    file.play();
    amp.input(file);
  }
}

float easeInOutQuint(float t) {
  return t<.5 ? 16*t*t*t*t*t : 1+16*(--t)*t*t*t*t;
}