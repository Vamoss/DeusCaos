class Dot
{
  PVector pos;
  PVector destPos;
  float velocity;
  float counter;
  float size;
  float sizeSin;
  float sizeSinStep;
  float step;
  float ease = 0.05;
  
  void setup() {
   counter = random(1000);
   pos = new PVector();
   destPos = new PVector();
   velocity = random(0.005, 0.01); 
   step = random(1000);
   size = random(5, 15);
   sizeSinStep = random(1000);
  }
  
  void update(boolean organize){
    if(organize){
      destPos.x = (round(pos.x/(float)width*2)*width/2.);
      destPos.y = (round(pos.y/(float)height*2)*height/2.);
      destPos.z = (round(pos.z/(float)height*2)*height/2.);
      if(destPos.x==0 && destPos.y==0 && destPos.z==0){
        destPos.x = width/2.;
      }
    }else{
      counter+=velocity;
      destPos.x = (noise(counter*0.5+step)-0.5)*width*2;
      destPos.y = (noise(counter*0.3+step)-0.5)*height*2;
      destPos.z = (noise(counter*0.1+step)-0.5)*height*2;
    }
    pos.x += (destPos.x-pos.x)*ease;
    pos.y += (destPos.y-pos.y)*ease;
    pos.z += (destPos.z-pos.z)*ease;
    sizeSin = abs(sin(frameCount/100.+sizeSinStep)*size)+5;
  }
  
  void draw(){
    pushMatrix();
    translate(pos.x, pos.y, pos.z);
    sphere(sizeSin);
    popMatrix();
  }
}