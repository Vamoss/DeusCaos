
#ifdef GL_ES
precision highp float;
#endif

// Processing specific input
uniform float time;
uniform vec2 resolution;
uniform vec2 mouse;

// Layer between Processing and Shadertoy uniforms
vec3 iResolution = vec3(resolution,0.0);
float iGlobalTime = time;

uniform vec2 mousePressed; // (0.0,0.0) no click, (1.0,1.0) left mouse button pressed
vec4 iMouse = vec4(mouse.xy,mousePressed.xy);



// based on: https://www.shadertoy.com/view/Xdf3zB
// Implementation of equi-angular sampling for raymarching through homogenous media
// 2013 @sjb3d

#define PI              3.1415926535
#define SIGMA           0.3
#define STEP_COUNT      16
#define DIST_MAX        10.0
#define LIGHT_POWER     16.0
#define SURFACE_ALBEDO  0.3
#define EPS             0.01
#define BALL_AMOUNT     60
#define time            iGlobalTime

uniform float posX[BALL_AMOUNT];
uniform float posY[BALL_AMOUNT];
uniform float posZ[BALL_AMOUNT];
uniform float size[BALL_AMOUNT];
uniform float rotate;
uniform float intensity;

// shamelessly stolen from iq!
float hash(float n)
{
    return fract(sin(n)*43758.5453123);
}

void sampleCamera(vec2 fragCoord, vec2 u, out vec3 rayOrigin, out vec3 rayDir)
{
  vec2 filmUv = (fragCoord.xy + u)/iResolution.xy;
  
  float tx = (2.0*filmUv.x - 1.0)*(iResolution.x/iResolution.y);
  float ty = (1.0 - 2.0*filmUv.y);
  
  rayOrigin = vec3( 4.0*cos(rotate), 0.0, 4.0*sin(rotate) );
  vec3 ta = vec3( 0.0, 0.0, 0.0 );
  
  // camera matrix
  vec3 ww = normalize( ta - rayOrigin );
  vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
  vec3 vv = normalize( cross(uu,ww));
  // create view ray
  rayDir = normalize( tx*uu + ty*vv + 1.5*ww );
}

void intersectSphere(
  vec3 rayOrigin,
  vec3 rayDir,
  vec3 sphereCentre,
  float sphereRadius,
  inout float rayT,
  inout vec3 geomNormal)
{
  // ray: x = o + dt, sphere: (x - c).(x - c) == r^2
  // let p = o - c, solve: (dt + p).(dt + p) == r^2
  //
  // => (d.d)t^2 + 2(p.d)t + (p.p - r^2) == 0
  vec3 p = rayOrigin - sphereCentre;
  vec3 d = rayDir;
  float a = dot(d, d);
  float b = 2.0*dot(p, d);
  float c = dot(p, p) - sphereRadius*sphereRadius;
  float q = b*b - 4.0*a*c;
  if (q > 0.0) {
    float denom = 0.5/a;
    float z1 = -b*denom;
    float z2 = abs(sqrt(q)*denom);
    float t1 = z1 - z2;
    float t2 = z1 + z2;
    bool intersected = false;
    if (0.0 < t1 && t1 < rayT) {
      intersected = true;
      rayT = t1;
    } else if (0.0 < t2 && t2 < rayT) {
      intersected = true;
      rayT = t2;
    }
    if (intersected) {
      geomNormal = normalize(p + d*rayT);
    }
  }
}

void intersectScene(
  vec3 rayOrigin,
  vec3 rayDir,
  inout float rayT,
  inout vec3 geomNormal)
{
    for (int stepIndex = 0; stepIndex < BALL_AMOUNT; ++stepIndex)
    { 
        intersectSphere(rayOrigin, rayDir, vec3( posX[stepIndex], posY[stepIndex], posZ[stepIndex]), size[stepIndex], rayT, geomNormal);
    }
}

void sampleUniform(
  float u,
  float maxDistance,
  out float dist,
  out float pdf)
{
  dist = u*maxDistance;
  pdf = 1.0/maxDistance;
}

void sampleEquiAngular(
  float u,
  float maxDistance,
  vec3 rayOrigin,
  vec3 rayDir,
  vec3 lightPos,
  out float dist,
  out float pdf)
{
  // get coord of closest point to light along (infinite) ray
  float delta = dot(lightPos - rayOrigin, rayDir);
  
  // get distance this point is from light
  float D = length(rayOrigin + delta*rayDir - lightPos);

  // get angle of endpoints
  float thetaA = atan(0.0 - delta, D);
  float thetaB = atan(maxDistance - delta, D);
  
  // take sample
  float t = D*tan(mix(thetaA, thetaB, u));
  dist = delta + t;
  pdf = D/((thetaB - thetaA)*(D*D + t*t));
}

void main(void)
{
  vec2 fragCoord = gl_FragCoord.xy;
  vec2 uv = fragCoord.xy / iResolution.xy;
  
  //fragCoord.x += intensity * 50.;
  vec3 lightPos = vec3(0.0);//vec3(0.8*sin(iGlobalTime*3.2/4.0), 0.8*sin(iGlobalTime*1.2/4.0), 0.0);
  vec3 lightIntensity = vec3(LIGHT_POWER*intensity);
  vec3 surfIntensity = vec3(SURFACE_ALBEDO/PI);
  vec3 particleIntensity = vec3(1.0/(4.0*PI));
  
  vec3 rayOrigin, rayDir;
  sampleCamera((fragCoord+uv,fragCoord+uv), vec2(0.5, 0.5), rayOrigin, rayDir);
  
  vec3 col = vec3(0.0);
  float t = DIST_MAX;
  {
    vec3 n;
    intersectScene(rayOrigin, rayDir, t, n);
    
    if (t < DIST_MAX) {
      // connect surface to light
      vec3 surfPos = rayOrigin + t*rayDir;
      vec3 lightVec = lightPos - surfPos;
      vec3 lightDir = normalize(lightVec);
      vec3 cameraDir = -rayDir;
      float nDotL = dot(n, lightDir);
      float nDotC = dot(n, cameraDir);
      
      // only handle BRDF if entry and exit are same hemisphere
      //if (nDotL*nDotC > 0.0) {
        float d = length(lightVec);
        float t2 = d;
        vec3 n2;
        vec3 rayDir = normalize(lightVec);
        intersectScene(surfPos + EPS*rayDir, rayDir, t2, n2);
                
        // accumulate surface response if not occluded
        if (t2 == d) {
          float trans = exp(-SIGMA*(d + t));
          float geomTerm = abs(nDotL)/dot(lightVec, lightVec);
          col = surfIntensity*lightIntensity*geomTerm*trans;
        }
      //}
    }
  }
  
  float offset = hash(fragCoord.y*iResolution.x + fragCoord.x + iGlobalTime);
  for (int stepIndex = 0; stepIndex < STEP_COUNT; ++stepIndex) {
    float u = (float(stepIndex)+offset)/float(STEP_COUNT);
    
    // sample along ray from camera to surface
    float x;
    float pdf;
    sampleEquiAngular(u, t, rayOrigin, rayDir, lightPos, x, pdf);
    
    // adjust for number of ray samples
    pdf *= float(STEP_COUNT);
    
    // connect to light and check shadow ray
    vec3 particlePos = rayOrigin + x*rayDir;
    vec3 lightVec = lightPos - particlePos;
    float d = length(lightVec);
    float t2 = d;
    vec3 n2;
    intersectScene(particlePos, normalize(lightVec), t2, n2);
    
    // accumulate particle response if not occluded
    if (t2 == d) {
      float trans = exp(-SIGMA*(d + x));
      float geomTerm = 1.0/dot(lightVec, lightVec);
      col += SIGMA*particleIntensity*lightIntensity*geomTerm*trans/pdf;
    }
  }
  col = pow(col, vec3(1.0/2.2));

  gl_FragColor = vec4(col, 1.0);
}