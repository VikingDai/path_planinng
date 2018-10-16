%% MINIMUM JERK TRAJ
% ts=linspace(0,3,4);

ts=[0.0,0.8,1.5,3];
ys=[1 2 1.5 2.5];
xs=[1 2 3 4];
zs=[0 0 0 0];
xdot0=0;
ydot0=0;
zdot0=0;
w_j=0.0005;
[pxs,pys,pzs]=min_jerk_soft(ts,xs,ys,zs,xdot0,ydot0,zdot0,w_j);

%% PLOT 
plot_poly_spline(ts,xs,ys,zs,pxs,pys,pzs)





