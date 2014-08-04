Tween={}local function a(b)if b.target~=nil then Daneel.Debug.StackTrace.BeginFunction("GetTweenerProperty",b)local c=nil;c=b.target[b.property]if c==nil then local d="Get"..string.ucfirst(b.property)if b.target[d]~=nil then c=b.target[d](b.target)end end;Daneel.Debug.StackTrace.EndFunction()return c end end;local function e(b,c)if b.target~=nil then Daneel.Debug.StackTrace.BeginFunction("SetTweenerProperty",b,c)if b.valueType=="string"then if type(c)=="number"and c>=#b.stringValue+1 then local f=b.startStringValue..b.endStringValue:sub(1,c)if f~=b.stringValue then b.stringValue=f;c=f else return end else return end end;if b.target[b.property]==nil then local d="Set"..string.ucfirst(b.property)if b.target[d]~=nil then b.target[d](b.target,b.property)end else b.target[b.property]=c end;Daneel.Debug.StackTrace.EndFunction()end end;Tween.Tweener={tweeners={}}Tween.Tweener.__index=Tween.Tweener;setmetatable(Tween.Tweener,{__call=function(g,...)return g.New(...)end})function Tween.Tweener.__tostring(b)return"Tweener: "..b.id end;function Tween.Tweener.New(h,i,j,k,l,m)Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.New",h,i,j,k,m)local n="Tween.Tweener.New(target, property, endValue, duration[, params]) : "local b=table.copy(Tween.Config.tweener)setmetatable(b,Tween.Tweener)b.id=Daneel.Utilities.GetId()local o=type(h)local p=nil;if o=="table"then p=getmetatable(h)end;if o=="number"or o=="string"or p==Vector2 or p==Vector3 then m=l;l=k;k=j;j=i;local q=h;n="Tween.Tweener.New(startValue, endValue, duration[, onCompleteCallback, params]) : "Daneel.Debug.CheckArgType(k,"duration","number",n)if type(l)=="table"then m=l;l=nil end;Daneel.Debug.CheckOptionalArgType(l,"onCompleteCallback","function",n)Daneel.Debug.CheckOptionalArgType(m,"params","table",n)b.startValue=q;b.endValue=j;b.duration=k;if l~=nil then b.OnComplete=l end;if m~=nil then b:Set(m)end elseif i==nil then Daneel.Debug.CheckArgType(h,"params","table",n)n="Tween.Tweener.New(params) : "b:Set(h)else Daneel.Debug.CheckArgType(h,"target","table",n)Daneel.Debug.CheckArgType(i,"property","string",n)Daneel.Debug.CheckArgType(k,"duration","number",n)if type(l)=="table"then m=l;l=nil end;Daneel.Debug.CheckOptionalArgType(l,"onCompleteCallback","function",n)Daneel.Debug.CheckOptionalArgType(m,"params","table",n)b.target=h;b.property=i;b.endValue=j;b.duration=k;if l~=nil then b.OnComplete=l end;if m~=nil then b:Set(m)end end;if b.endValue==nil then error("Tween.Tweener.New(): 'endValue' property is nil for tweener: "..tostring(b))end;if b.startValue==nil then b.startValue=a(b)end;if b.target~=nil then b.gameObject=b.target.gameObject end;b.valueType=Daneel.Debug.GetType(b.startValue)if b.valueType=="string"then b.startStringValue=b.startValue;b.stringValue=b.startStringValue;b.endStringValue=b.endValue;b.startValue=1;b.endValue=#b.endStringValue end;Tween.Tweener.tweeners[b.id]=b;Daneel.Debug.StackTrace.EndFunction()return b end;function Tween.Tweener.Set(b,m)Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.Set",b,m)local n="Tween.Tweener.Set(tweener, params) : "Daneel.Debug.CheckArgType(b,"tweener","Tween.Tweener",n)for r,c in pairs(m)do b[r]=c end;Daneel.Debug.StackTrace.EndFunction()return b end;function Tween.Tweener.Play(b)if b.isEnabled==false then return end;Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.Play",b)local n="Tween.Tweener.Play(tweener) : "Daneel.Debug.CheckArgType(b,"tweener","Tween.Tweener",n)b.isPaused=false;Daneel.Event.Fire(b,"OnPlay",b)Daneel.Debug.StackTrace.EndFunction()end;function Tween.Tweener.Pause(b)if b.isEnabled==false then return end;Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.Pause",b)local n="Tween.Tweener.Pause(tweener) : "Daneel.Debug.CheckArgType(b,"tweener","Tween.Tweener",n)b.isPaused=true;Daneel.Event.Fire(b,"OnPause",b)Daneel.Debug.StackTrace.EndFunction()end;function Tween.Tweener.Restart(b)if b.isEnabled==false then return end;Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.Restart",b)local n="Tween.Tweener.Restart(tweener) : "Daneel.Debug.CheckArgType(b,"tweener","Tween.Tweener",n)b.elapsed=0;b.fullElapsed=0;b.elapsedDelay=0;b.completedLoops=0;b.isCompleted=false;b.hasStarted=false;local q=b.startValue;if b.loopType=="yoyo"and b.completedLoops%2~=0 then q=b.endValue end;if b.target~=nil then e(b,q)end;b.value=q;Daneel.Debug.StackTrace.EndFunction()end;function Tween.Tweener.Complete(b)if b.isEnabled==false or b.loops==-1 then return end;Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.Complete",b)local n="Tween.Tweener.Complete( tweener ) : "Daneel.Debug.CheckArgType(b,"tweener","Tween.Tweener",n)b.isCompleted=true;local j=b.endValue;if b.loopType=="yoyo"then if b.loops%2==0 and b.completedLoops%2==0 then j=b.startValue elseif b.loops%2~=0 and b.completedLoops%2~=0 then j=b.startValue end end;if b.target~=nil then e(b,j)end;b.value=j;Daneel.Event.Fire(b,"OnComplete",b)if b.destroyOnComplete then b:Destroy()end;Daneel.Debug.StackTrace.EndFunction()end;local function t(u)return u.isDestroyed==true or u.inner==nil end;function Tween.Tweener.IsTargetDestroyed(b)if b.target~=nil then if b.target.isDestroyed then return true end;if b.target.gameObject~=nil and t(b.target.gameObject)then return true end end;if b.gameObject~=nil and t(b.gameObject)then return true end;return false end;function Tween.Tweener.Destroy(b)Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.Destroy",b)local n="Tween.Tweener.Destroy( tweener ) : "Daneel.Debug.CheckArgType(b,"tweener","Tween.Tweener",n)b.isEnabled=false;b.isPaused=true;b.target=nil;b.duration=0;Tween.Tweener.tweeners[b.id]=nil;CraftStudio.Destroy(b)Daneel.Debug.StackTrace.EndFunction()end;function Tween.Tweener.Update(b,v)if b.isEnabled==false then return end;Daneel.Debug.StackTrace.BeginFunction("Tween.Tweener.Update",b,v)local n="Tween.Tweener.Update(tweener[, deltaDuration]) : "Daneel.Debug.CheckArgType(b,"tweener","Tween.Tweener",n)Daneel.Debug.CheckArgType(v,"deltaDuration","number",n)if Tween.Ease[b.easeType]==nil then if Daneel.Config.debug.enableDebug then print("Tween.Tweener.Update() : Easing '"..tostring(b.easeType).."' for tweener ID '"..tween.id.."' does not exists. Setting it back for the default easing '"..Tween.Config.tweener.easeType.."'.")end;b.easeType=Tween.Config.tweener.easeType end;if v~=nil then b.elapsed=b.elapsed+v;b.fullElapsed=b.fullElapsed+v end;local c=nil;if b.elapsed>b.duration then b.isCompleted=true;b.elapsed=b.duration;if b.isRelative==true then c=b.startValue+b.endValue else c=b.endValue end else if b.valueType=="Vector3"then c=Vector3:New(Tween.Ease[b.easeType](b.elapsed,b.startValue.x,b.diffValue.x,b.duration),Tween.Ease[b.easeType](b.elapsed,b.startValue.y,b.diffValue.y,b.duration),Tween.Ease[b.easeType](b.elapsed,b.startValue.z,b.diffValue.z,b.duration))elseif b.valueType=="Vector2"then c=Vector2.New(Tween.Ease[b.easeType](b.elapsed,b.startValue.x,b.diffValue.x,b.duration),Tween.Ease[b.easeType](b.elapsed,b.startValue.y,b.diffValue.y,b.duration))else c=Tween.Ease[b.easeType](b.elapsed,b.startValue,b.diffValue,b.duration)end end;if b.target~=nil then e(b,c)end;b.value=c;Daneel.Event.Fire(b,"OnUpdate",b)Daneel.Debug.StackTrace.EndFunction()end;Tween.Timer={}Tween.Timer.__index=Tween.Tweener;setmetatable(Tween.Timer,{__call=function(g,...)return g.New(...)end})function Tween.Timer.New(k,w,x,m)Daneel.Debug.StackTrace.BeginFunction("Tween.Timer.New",k,w,x,m)local n="Tween.Timer.New( duration, callback[, isInfiniteLoop, params] ) : "if type(x)=="table"then m=x;n="Tween.Timer.New( duration, callback[, params] ) : "end;Daneel.Debug.CheckArgType(k,"duration","number",n)Daneel.Debug.CheckArgType(w,"callback",{"function","userdata"},n)Daneel.Debug.CheckOptionalArgType(m,"params","table",n)local b=table.copy(Tween.Config.tweener)setmetatable(b,Tween.Tweener)b.id=Daneel.Utilities.GetId()b.startValue=k;b.endValue=0;b.duration=k;if x==true then b.loops=-1;b.OnLoopComplete=w else b.OnComplete=w end;if m~=nil then b:Set(m)end;Tween.Tweener.tweeners[b.id]=b;Daneel.Debug.StackTrace.EndFunction()return b end;Daneel.modules.Tween=Tween;function Tween.DefaultConfig()local y={tweener={isEnabled=true,isPaused=false,delay=0.0,duration=0.0,durationType="time",startValue=nil,endValue=0.0,loops=0,loopType="simple",easeType="linear",isRelative=false,destroyOnComplete=true,destroyOnSceneLoad=true,updateInterval=1,Id=-1,hasStarted=false,isCompleted=false,elapsed=0,fullElapsed=0,elapsedDelay=0,completedLoops=0,diffValue=0.0,value=0.0,frameCount=0},objects={["Tween.Tweener"]=Tween.Tweener},propertiesByComponentName={transform={"scale","localScale","position","localPosition","eulerAngles","localEulerAngles"},modelRenderer={"opacity"},mapRenderer={"opacity"},textRenderer={"text","opacity"},camera={"fov"}}}return y end;Tween.Config=Tween.DefaultConfig()function Tween.Awake()if Tween.Config.componentNamesByProperty==nil then local z={}for A,B in pairs(Tween.Config.propertiesByComponentName)do for C=1,#B do local i=B[C]z[i]=z[i]or{}table.insert(z[i],A)end end;Tween.Config.componentNamesByProperty=z end;for D,b in pairs(Tween.Tweener.tweeners)do if b.destroyOnSceneLoad then b:Destroy()end end end;function Tween.Update()for D,b in pairs(Tween.Tweener.tweeners)do if b:IsTargetDestroyed()then b:Destroy()end;if b.isEnabled==true and b.isPaused==false and b.isCompleted==false and b.duration>0 then b.frameCount=b.frameCount+1;if b.frameCount%b.updateInterval==0 then local v=Daneel.Time.deltaTime*b.updateInterval;if b.durationType=="realTime"then v=Daneel.Time.realDeltaTime*b.updateInterval elseif b.durationType=="frame"then v=b.updateInterval end;if v>0 then if b.elapsedDelay>=b.delay then if b.hasStarted==false then b.hasStarted=true;if b.startValue==nil then if b.target~=nil then b.startValue=a(b)else error("Tween.Update() : startValue is nil but no target is set for tweener: "..tostring(b))end elseif b.target~=nil then e(b,b.startValue)end;b.value=b.startValue;if b.isRelative==true then b.diffValue=b.endValue else b.diffValue=b.endValue-b.startValue end;Daneel.Event.Fire(b,"OnStart",b)end;b:Update(v)else b.elapsedDelay=b.elapsedDelay+v end;if b.isCompleted==true then b.completedLoops=b.completedLoops+1;if b.loops==-1 or b.completedLoops<b.loops then b.isCompleted=false;b.elapsed=0;if b.loopType:lower()=="yoyo"then local q=b.startValue;if b.isRelative then b.startValue=b.value;b.endValue=-b.endValue;b.diffValue=b.endValue else b.startValue=b.endValue;b.endValue=q;b.diffValue=-b.diffValue end elseif b.target~=nil then e(b,b.startValue)end;b.value=b.startValue;Daneel.Event.Fire(b,"OnLoopComplete",b)else Daneel.Event.Fire(b,"OnComplete",b)if b.destroyOnComplete and b.Destroy~=nil then b:Destroy()end end end end end end end end;local function E(u,i)local F=nil;if Daneel.modules.GUI~=nil and u.hud~=nil and i=="position"or i=="localPosition"then F=u.hud else local G=Tween.Config.componentNamesByProperty[i]if G~=nil then for C=1,#G do F=u[G[C]]if F~=nil then break end end end end;if F==nil then error("Tween: resolveTarget(): Couldn't resolve the target for property '"..i.."' and gameObject: "..tostring(u))end;return F end;function GameObject.Animate(u,i,j,k,l,m)local F=nil;if type(l)=="table"and m==nil then m=l;l=nil end;if m~=nil and m.target~=nil then F=m.target else F=E(u,i)end;return Tween.Tweener.New(F,i,j,k,l,m)end;function GameObject.AnimateAndDestroy(u,i,j,k,m)local F=nil;if m~=nil and m.target~=nil then F=m.target else F=E(u,i)end;return Tween.Tweener.New(F,i,j,k,function()u:Destroy()end,m)end;local H=math.pow;local I=math.sin;local J=math.cos;local K=math.pi;local L=math.sqrt;local M=math.abs;local N=math.asin;local function O(z,P,Q,R)return Q*z/R+P end;local function S(z,P,Q,R)z=z/R;return Q*H(z,2)+P end;local function T(z,P,Q,R)z=z/R;return-Q*z*z-2+P end;local function U(z,P,Q,R)z=z/R*2;if z<1 then return Q/2*H(z,2)+P else return-Q/2*(z-1)*z-3-1+P end end;local function V(z,P,Q,R)if z<R/2 then return T(z*2,P,Q/2,R)else return S(z*2-R,P+Q/2,Q/2,R)end end;local function W(z,P,Q,R)z=z/R;return Q*H(z,3)+P end;local function X(z,P,Q,R)z=z/R-1;return Q*H(z,3)+1+P end;local function Y(z,P,Q,R)z=z/R*2;if z<1 then return Q/2*z*z*z+P else z=z-2;return Q/2*z*z*z+2+P end end;local function Z(z,P,Q,R)if z<R/2 then return X(z*2,P,Q/2,R)else return W(z*2-R,P+Q/2,Q/2,R)end end;local function _(z,P,Q,R)z=z/R;return Q*H(z,4)+P end;local function a0(z,P,Q,R)z=z/R-1;return-Q*H(z,4)-1+P end;local function a1(z,P,Q,R)z=z/R*2;if z<1 then return Q/2*H(z,4)+P else z=z-2;return-Q/2*H(z,4)-2+P end end;local function a2(z,P,Q,R)if z<R/2 then return a0(z*2,P,Q/2,R)else return _(z*2-R,P+Q/2,Q/2,R)end end;local function a3(z,P,Q,R)z=z/R;return Q*H(z,5)+P end;local function a4(z,P,Q,R)z=z/R-1;return Q*H(z,5)+1+P end;local function a5(z,P,Q,R)z=z/R*2;if z<1 then return Q/2*H(z,5)+P else z=z-2;return Q/2*H(z,5)+2+P end end;local function a6(z,P,Q,R)if z<R/2 then return a4(z*2,P,Q/2,R)else return a3(z*2-R,P+Q/2,Q/2,R)end end;local function a7(z,P,Q,R)return-Q*J(z/R*K/2)+Q+P end;local function a8(z,P,Q,R)return Q*I(z/R*K/2)+P end;local function a9(z,P,Q,R)return-Q/2*J(K*z/R)-1+P end;local function aa(z,P,Q,R)if z<R/2 then return a8(z*2,P,Q/2,R)else return a7(z*2-R,P+Q/2,Q/2,R)end end;local function ab(z,P,Q,R)if z==0 then return P else return Q*H(2,10*z/R-1)+P-Q*0.001 end end;local function ac(z,P,Q,R)if z==R then return P+Q else return Q*1.001*-H(2,-10*z/R)+1+P end end;local function ad(z,P,Q,R)if z==0 then return P end;if z==R then return P+Q end;z=z/R*2;if z<1 then return Q/2*H(2,10*z-1)+P-Q*0.0005 else z=z-1;return Q/2*1.0005*-H(2,-10*z)+2+P end end;local function ae(z,P,Q,R)if z<R/2 then return ac(z*2,P,Q/2,R)else return ab(z*2-R,P+Q/2,Q/2,R)end end;local function af(z,P,Q,R)z=z/R;return-Q*L(1-H(z,2))-1+P end;local function ag(z,P,Q,R)z=z/R-1;return Q*L(1-H(z,2))+P end;local function ah(z,P,Q,R)z=z/R*2;if z<1 then return-Q/2*L(1-z*z)-1+P else z=z-2;return Q/2*L(1-z*z)+1+P end end;local function ai(z,P,Q,R)if z<R/2 then return ag(z*2,P,Q/2,R)else return af(z*2-R,P+Q/2,Q/2,R)end end;local function aj(z,P,Q,R,ak,al)if z==0 then return P end;z=z/R;if z==1 then return P+Q end;if not al then al=R*0.3 end;local s;if not ak or ak<M(Q)then ak=Q;s=al/4 else s=al/2*K*N(Q/ak)end;z=z-1;return-(ak*H(2,10*z)*I((z*R-s)*2*K/al))+P end;local function am(z,P,Q,R,ak,al)if z==0 then return P end;z=z/R;if z==1 then return P+Q end;if not al then al=R*0.3 end;local s;if not ak or ak<M(Q)then ak=Q;s=al/4 else s=al/2*K*N(Q/ak)end;return ak*H(2,-10*z)*I((z*R-s)*2*K/al)+Q+P end;local function an(z,P,Q,R,ak,al)if z==0 then return P end;z=z/R*2;if z==2 then return P+Q end;if not al then al=R*0.3*1.5 end;if not ak then ak=0 end;if not ak or ak<M(Q)then ak=Q;s=al/4 else s=al/2*K*N(Q/ak)end;if z<1 then z=z-1;return-0.5*ak*H(2,10*z)*I((z*R-s)*2*K/al)+P else z=z-1;return ak*H(2,-10*z)*I((z*R-s)*2*K/al)*0.5+Q+P end end;local function ao(z,P,Q,R,ak,al)if z<R/2 then return am(z*2,P,Q/2,R,ak,al)else return aj(z*2-R,P+Q/2,Q/2,R,ak,al)end end;local function ap(z,P,Q,R,s)if not s then s=1.70158 end;z=z/R;return Q*z*z*(s+1)*z-s+P end;local function aq(z,P,Q,R,s)if not s then s=1.70158 end;z=z/R-1;return Q*z*z*(s+1)*z+s+1+P end;local function ar(z,P,Q,R,s)if not s then s=1.70158 end;s=s*1.525;z=z/R*2;if z<1 then return Q/2*z*z*(s+1)*z-s+P else z=z-2;return Q/2*z*z*(s+1)*z+s+2+P end end;local function as(z,P,Q,R,s)if z<R/2 then return aq(z*2,P,Q/2,R,s)else return ap(z*2-R,P+Q/2,Q/2,R,s)end end;local function at(z,P,Q,R)z=z/R;if z<1/2.75 then return Q*7.5625*z*z+P elseif z<2/2.75 then z=z-1.5/2.75;return Q*7.5625*z*z+0.75+P elseif z<2.5/2.75 then z=z-2.25/2.75;return Q*7.5625*z*z+0.9375+P else z=z-2.625/2.75;return Q*7.5625*z*z+0.984375+P end end;local function au(z,P,Q,R)return Q-at(R-z,0,Q,R)+P end;local function av(z,P,Q,R)if z<R/2 then return au(z*2,0,Q,R)*0.5+P else return at(z*2-R,0,Q,R)*0.5+Q*.5+P end end;local function aw(z,P,Q,R)if z<R/2 then return at(z*2,P,Q/2,R)else return au(z*2-R,P+Q/2,Q/2,R)end end;Tween.Ease={linear=O,inQuad=S,outQuad=T,inOutQuad=U,outInQuad=V,inCubic=W,outCubic=X,inOutCubic=Y,outInCubic=Z,inQuart=_,outQuart=a0,inOutQuart=a1,outInQuart=a2,inQuint=a3,outQuint=a4,inOutQuint=a5,outInQuint=a6,inSine=a7,outSine=a8,inOutSine=a9,outInSine=aa,inExpo=ab,outExpo=ac,inOutExpo=ad,outInExpo=ae,inCirc=af,outCirc=ag,inOutCirc=ah,outInCirc=ai,inElastic=aj,outElastic=am,inOutElastic=an,outInElastic=ao,inBack=ap,outBack=aq,inOutBack=ar,outInBack=as,inBounce=au,outBounce=at,inOutBounce=av,outInBounce=aw}

----------------------------------------------------------------------------------
-- Easing equations

local pow = math.pow
local sin = math.sin
local cos = math.cos
local pi = math.pi
local sqrt = math.sqrt
local abs = math.abs
local asin = math.asin

local function linear(t, b, c, d)
  return c * t / d + b
end

local function inQuad(t, b, c, d)
  t = t / d
  return c * pow(t, 2) + b
end

local function outQuad(t, b, c, d)
  t = t / d
  return -c * t * (t - 2) + b
end

local function inOutQuad(t, b, c, d)
  t = t / d * 2
  if t < 1 then
    return c / 2 * pow(t, 2) + b
  else
    return -c / 2 * ((t - 1) * (t - 3) - 1) + b
  end
end

local function outInQuad(t, b, c, d)
  if t < d / 2 then
    return outQuad (t * 2, b, c / 2, d)
  else
    return inQuad((t * 2) - d, b + c / 2, c / 2, d)
  end
end

local function inCubic (t, b, c, d)
  t = t / d
  return c * pow(t, 3) + b
end

local function outCubic(t, b, c, d)
  t = t / d - 1
  return c * (pow(t, 3) + 1) + b
end

local function inOutCubic(t, b, c, d)
  t = t / d * 2
  if t < 1 then
    return c / 2 * t * t * t + b
  else
    t = t - 2
    return c / 2 * (t * t * t + 2) + b
  end
end

local function outInCubic(t, b, c, d)
  if t < d / 2 then
    return outCubic(t * 2, b, c / 2, d)
  else
    return inCubic((t * 2) - d, b + c / 2, c / 2, d)
  end
end

local function inQuart(t, b, c, d)
  t = t / d
  return c * pow(t, 4) + b
end

local function outQuart(t, b, c, d)
  t = t / d - 1
  return -c * (pow(t, 4) - 1) + b
end

local function inOutQuart(t, b, c, d)
  t = t / d * 2
  if t < 1 then
    return c / 2 * pow(t, 4) + b
  else
    t = t - 2
    return -c / 2 * (pow(t, 4) - 2) + b
  end
end

local function outInQuart(t, b, c, d)
  if t < d / 2 then
    return outQuart(t * 2, b, c / 2, d)
  else
    return inQuart((t * 2) - d, b + c / 2, c / 2, d)
  end
end

local function inQuint(t, b, c, d)
  t = t / d
  return c * pow(t, 5) + b
end

local function outQuint(t, b, c, d)
  t = t / d - 1
  return c * (pow(t, 5) + 1) + b
end

local function inOutQuint(t, b, c, d)
  t = t / d * 2
  if t < 1 then
    return c / 2 * pow(t, 5) + b
  else
    t = t - 2
    return c / 2 * (pow(t, 5) + 2) + b
  end
end

local function outInQuint(t, b, c, d)
  if t < d / 2 then
    return outQuint(t * 2, b, c / 2, d)
  else
    return inQuint((t * 2) - d, b + c / 2, c / 2, d)
  end
end

local function inSine(t, b, c, d)
  return -c * cos(t / d * (pi / 2)) + c + b
end

local function outSine(t, b, c, d)
  return c * sin(t / d * (pi / 2)) + b
end

local function inOutSine(t, b, c, d)
  return -c / 2 * (cos(pi * t / d) - 1) + b
end

local function outInSine(t, b, c, d)
  if t < d / 2 then
    return outSine(t * 2, b, c / 2, d)
  else
    return inSine((t * 2) -d, b + c / 2, c / 2, d)
  end
end

local function inExpo(t, b, c, d)
  if t == 0 then
    return b
  else
    return c * pow(2, 10 * (t / d - 1)) + b - c * 0.001
  end
end

local function outExpo(t, b, c, d)
  if t == d then
    return b + c
  else
    return c * 1.001 * (-pow(2, -10 * t / d) + 1) + b
  end
end

local function inOutExpo(t, b, c, d)
  if t == 0 then return b end
  if t == d then return b + c end
  t = t / d * 2
  if t < 1 then
    return c / 2 * pow(2, 10 * (t - 1)) + b - c * 0.0005
  else
    t = t - 1
    return c / 2 * 1.0005 * (-pow(2, -10 * t) + 2) + b
  end
end

local function outInExpo(t, b, c, d)
  if t < d / 2 then
    return outExpo(t * 2, b, c / 2, d)
  else
    return inExpo((t * 2) - d, b + c / 2, c / 2, d)
  end
end

local function inCirc(t, b, c, d)
  t = t / d
  return(-c * (sqrt(1 - pow(t, 2)) - 1) + b)
end

local function outCirc(t, b, c, d)
  t = t / d - 1
  return(c * sqrt(1 - pow(t, 2)) + b)
end

local function inOutCirc(t, b, c, d)
  t = t / d * 2
  if t < 1 then
    return -c / 2 * (sqrt(1 - t * t) - 1) + b
  else
    t = t - 2
    return c / 2 * (sqrt(1 - t * t) + 1) + b
  end
end

local function outInCirc(t, b, c, d)
  if t < d / 2 then
    return outCirc(t * 2, b, c / 2, d)
  else
    return inCirc((t * 2) - d, b + c / 2, c / 2, d)
  end
end

local function inElastic(t, b, c, d, a, p)
  if t == 0 then return b end

  t = t / d

  if t == 1 then return b + c end

  if not p then p = d * 0.3 end

  local s

  if not a or a < abs(c) then
    a = c
    s = p / 4
  else
    s = p / (2 * pi) * asin(c/a)
  end

  t = t - 1

  return -(a * pow(2, 10 * t) * sin((t * d - s) * (2 * pi) / p)) + b
end

-- a: amplitud
-- p: period
local function outElastic(t, b, c, d, a, p)
  if t == 0 then return b end

  t = t / d

  if t == 1 then return b + c end

  if not p then p = d * 0.3 end

  local s

  if not a or a < abs(c) then
    a = c
    s = p / 4
  else
    s = p / (2 * pi) * asin(c/a)
  end

  return a * pow(2, -10 * t) * sin((t * d - s) * (2 * pi) / p) + c + b
end

-- p = period
-- a = amplitud
local function inOutElastic(t, b, c, d, a, p)
  if t == 0 then return b end

  t = t / d * 2

  if t == 2 then return b + c end

  if not p then p = d * (0.3 * 1.5) end
  if not a then a = 0 end

  if not a or a < abs(c) then
    a = c
    s = p / 4
  else
    s = p / (2 * pi) * asin(c / a)
  end

  if t < 1 then
    t = t - 1
    return -0.5 * (a * pow(2, 10 * t) * sin((t * d - s) * (2 * pi) / p)) + b
  else
    t = t - 1
    return a * pow(2, -10 * t) * sin((t * d - s) * (2 * pi) / p ) * 0.5 + c + b
  end
end

-- a: amplitud
-- p: period
local function outInElastic(t, b, c, d, a, p)
  if t < d / 2 then
    return outElastic(t * 2, b, c / 2, d, a, p)
  else
    return inElastic((t * 2) - d, b + c / 2, c / 2, d, a, p)
  end
end

local function inBack(t, b, c, d, s)
  if not s then s = 1.70158 end
  t = t / d
  return c * t * t * ((s + 1) * t - s) + b
end

local function outBack(t, b, c, d, s)
  if not s then s = 1.70158 end
  t = t / d - 1
  return c * (t * t * ((s + 1) * t + s) + 1) + b
end

local function inOutBack(t, b, c, d, s)
  if not s then s = 1.70158 end
  s = s * 1.525
  t = t / d * 2
  if t < 1 then
    return c / 2 * (t * t * ((s + 1) * t - s)) + b
  else
    t = t - 2
    return c / 2 * (t * t * ((s + 1) * t + s) + 2) + b
  end
end

local function outInBack(t, b, c, d, s)
  if t < d / 2 then
    return outBack(t * 2, b, c / 2, d, s)
  else
    return inBack((t * 2) - d, b + c / 2, c / 2, d, s)
  end
end

local function outBounce(t, b, c, d)
  t = t / d
  if t < 1 / 2.75 then
    return c * (7.5625 * t * t) + b
  elseif t < 2 / 2.75 then
    t = t - (1.5 / 2.75)
    return c * (7.5625 * t * t + 0.75) + b
  elseif t < 2.5 / 2.75 then
    t = t - (2.25 / 2.75)
    return c * (7.5625 * t * t + 0.9375) + b
  else
    t = t - (2.625 / 2.75)
    return c * (7.5625 * t * t + 0.984375) + b
  end
end

local function inBounce(t, b, c, d)
  return c - outBounce(d - t, 0, c, d) + b
end

local function inOutBounce(t, b, c, d)
  if t < d / 2 then
    return inBounce(t * 2, 0, c, d) * 0.5 + b
  else
    return outBounce(t * 2 - d, 0, c, d) * 0.5 + c * .5 + b
  end
end

local function outInBounce(t, b, c, d)
  if t < d / 2 then
    return outBounce(t * 2, b, c / 2, d)
  else
    return inBounce((t * 2) - d, b + c / 2, c / 2, d)
  end
end

-- Modifications for Daneel : replaced 'return {' by 'Tween.Ease = {'
Tween.Ease = {
  linear = linear,
  inQuad = inQuad,
  outQuad = outQuad,
  inOutQuad = inOutQuad,
  outInQuad = outInQuad,
  inCubic = inCubic ,
  outCubic = outCubic,
  inOutCubic = inOutCubic,
  outInCubic = outInCubic,
  inQuart = inQuart,
  outQuart = outQuart,
  inOutQuart = inOutQuart,
  outInQuart = outInQuart,
  inQuint = inQuint,
  outQuint = outQuint,
  inOutQuint = inOutQuint,
  outInQuint = outInQuint,
  inSine = inSine,
  outSine = outSine,
  inOutSine = inOutSine,
  outInSine = outInSine,
  inExpo = inExpo,
  outExpo = outExpo,
  inOutExpo = inOutExpo,
  outInExpo = outInExpo,
  inCirc = inCirc,
  outCirc = outCirc,
  inOutCirc = inOutCirc,
  outInCirc = outInCirc,
  inElastic = inElastic,
  outElastic = outElastic,
  inOutElastic = inOutElastic,
  outInElastic = outInElastic,
  inBack = inBack,
  outBack = outBack,
  inOutBack = inOutBack,
  outInBack = outInBack,
  inBounce = inBounce,
  outBounce = outBounce,
  inOutBounce = inOutBounce,
  outInBounce = outInBounce,
}
