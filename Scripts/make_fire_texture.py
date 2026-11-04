import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

W,H=512,256
rng=np.random.default_rng(7)
yy,xx=np.mgrid[0:H,0:W].astype(np.float64)
u=xx/W
v=yy/H
2*np.pi

def periodic_noise(base=0.0, fx_range=(1,12), fy_range=(1,6), waves=18, seed=0):
    r=np.random.default_rng(seed)
    z=np.zeros((H,W),dtype=np.float64)
    for _ in range(waves):
        fx=r.integers(fx_range[0],fx_range[1]+1)
        fy=r.integers(fy_range[0],fy_range[1]+1)
        ph=r.uniform(0,2*np.pi)
        amp=1.0/(1.0+fx*0.15+fy*0.25)
        z += amp*np.sin(2*np.pi*(fx*u+fy*v)+ph)
    z=(z-z.min())/(z.max()-z.min()+1e-9)
    return z

# Anisotropic noise: higher x frequency gives vertical streaks
n1=periodic_noise(fx_range=(2,18), fy_range=(1,4), waves=28, seed=1)
n2=periodic_noise(fx_range=(5,30), fy_range=(1,5), waves=30, seed=2)
n3=periodic_noise(fx_range=(1,8), fy_range=(1,3), waves=18, seed=3)
# domain-ish warp
warp=(n3-0.5)*0.45
heat=0.55*n1 + 0.30*n2 + 0.25*np.sin((u+warp)*2*np.pi*3 + v*2*np.pi*1.5)
heat=(heat-heat.min())/(heat.max()-heat.min()+1e-9)

# More heat towards lower portion so tongues point up
vertical=np.clip(1.15 - v*0.55, 0, 1.2)
heat=np.clip(heat*0.78 + vertical*0.30, 0, 1)
# deepen contrast
heat=np.clip((heat-0.18)/0.72, 0, 1)
gamma=1.15
heat=heat**gamma

# color map
stops=np.array([0.0,0.18,0.36,0.55,0.72,0.87,0.97,1.0])
colors=np.array([
 [26,1,0],
 [72,5,0],
 [155,16,0],
 [225,50,0],
 [255,105,0],
 [255,175,20],
 [255,225,100],
 [255,250,220],
],dtype=np.float64)
rgb=np.zeros((H,W,3),dtype=np.float64)
for c in range(3):
    rgb[:,:,c]=np.interp(heat,stops,colors[:,c])
rgb=np.clip(rgb,0,255).astype(np.uint8)
im=Image.fromarray(rgb,'RGB')
# add subtle glow/bloom
blur=im.filter(ImageFilter.GaussianBlur(2.0))
arr=np.maximum(np.array(im,dtype=np.float32),np.array(blur,dtype=np.float32)*0.65)
im=Image.fromarray(np.clip(arr,0,255).astype(np.uint8),'RGB')
out = Path(__file__).resolve().parent.parent / 'Resources' / 'FireTexture.png'
out.parent.mkdir(parents=True, exist_ok=True)
im.save(out)
print(out)
