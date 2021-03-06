function jerk_fun = jerk_fun(ax,bx,cx,dx,a0x,v0x,x0x,ay,by,cy,dy,a0y,v0y,x0y,az,bz,cz,dz,a0z,v0z,x0z,t)
%JERK_FUN
%    JERK_FUN = JERK_FUN(AX,BX,CX,DX,A0X,V0X,X0X,AY,BY,CY,DY,A0Y,V0Y,X0Y,AZ,BZ,CZ,DZ,A0Z,V0Z,X0Z,T)

%    This function was generated by the Symbolic Math Toolbox version 8.0.
%    24-Jan-2018 20:09:55

jerk_fun = t.*abs(ax+ay+az-(a0x.*(1.0./2.0)+a0y.*(1.0./2.0)+a0z.*(1.0./2.0)-bx-by-bz)./t+1.0./t.^2.*(cx+cy+cz-v0x-v0y-v0z)+1.0./t.^3.*(dx+dy+dz-x0x-x0y-x0z));
