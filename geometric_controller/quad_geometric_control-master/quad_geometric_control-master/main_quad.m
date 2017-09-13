function[varargout] =  main_quad(varargin)
% Geometric control of Quadrotor on SE(3)
% http://www.math.ucsd.edu/~mleok/pdf/LeLeMc2010_quadrotor.pdf
%% TRAJECTORY GENERATION

trajectory_gen

%% INITIALZING WORKSPACE
% ======================
% Clear workspace
% ---------------
% clear; 
% clc;

% Add Paths
% ----------
% Adding path to 'Geometric Control Toolbox'
addpath('./Geometry-Toolbox/');


%% INITIALZING PARAMETERS
% ======================
% System constants and parameters
data.params.mQ = 0.2 ;
data.params.J = diag([0.557, 0.557, 1.05]*10e-3);
data.params.g = 9.81 ;
data.params.e1 = [1;0;0] ;
data.params.e2 = [0;1;0] ;
data.params.e3 = [0;0;1] ;
data.params.p=p; % coefficients of polynomial  
data.params.n=n; % order of polynomial  

%% INTIALIZING - INTIAL CONDITIONS
% ================================
% Zero Position 
% -------------
xQ0 = [];
vQ0 = zeros(3,1);

R0 = RPYtoRot_ZXY(010*pi/180,0*pi/180, 0*pi/180) ;
Omega0 = zeros(3,1);

xQ0 = x0-ones(3,1);
vQ0 = dx0_real;
% 
R0=[1 0 0; 0 1 0 ; 0 0 1];
Omega0 = zeros(3,1);


% Zero Initial Error- Configuration
% ---------------------------------
% [trajd0] = get_nom_traj(data.params,get_flats(0));
% xQ0 = trajd0.xQ;
% vQ0 = trajd0.vQ;
% 
% R0 = trajd0.R;
% Omega0 = trajd0.Omega;

% state - structure
% -----------------
% [xL; vL; R; Omega]
% setting up x0 (initial state)
% -----------------------------
x_init = [xQ0; vQ0; reshape(R0,9,1); Omega0 ];

%% SIMULATION
% ==========
disp('Simulating...') ;
odeopts = odeset('RelTol', 1e-8, 'AbsTol', 1e-9) ;
% odeopts = [] ;
tspan=[t0_real tf_real];
data.params.tspan=tspan;
[t, x] = ode15s(@odefun_quadDynamics, tspan, x_init, odeopts, data) ;

% Computing Various Quantities
disp('Computing...') ;
ind = round(linspace(1, length(t), round(1*length(t)))) ;
% ind = 0:length(t);
for i = ind
   [~,xd_,f_,M_] =  odefun_quadDynamics(t(i),x(i,:)',data);
   xd(i,:) = xd_';
   psi_exL(i) = norm(x(i,1:3)-xd(i,1:3));
   psi_evL(i) = norm(x(i,4:6)-xd(i,4:6));
   f(i,1)= f_;
   M(i,:)= M_';
end


%% PLOTS
% =====
    figure;
    subplot(2,2,1);
    plot(t(ind),x(ind,1),'-g',t(ind),xd(ind,1),':r');
    grid on; title('x');legend('x','x_d');%axis equal;
    xlabel('time');ylabel('x [m]');
    subplot(2,2,2);
    plot(t(ind),x(ind,2),'-g',t(ind),xd(ind,2),':r');
    grid on; title('y');legend('y','y_d');%axis equal;
    xlabel('time');ylabel('y [m]');
    subplot(2,2,3);
    plot(t(ind),x(ind,3),'-g',t(ind),xd(ind,3),':r');
    grid on; title('z');legend('z','z_d');%axis equal;
    xlabel('time');ylabel('z [m]');
    subplot(2,2,4);
    
    plot3(x(ind,1),x(ind,2),x(ind,3),'-g',xd(ind,1),xd(ind,2),xd(ind,3),':r');
    
    grid on; title('trajectory');legend('traj','traj_d');%axis equal;
    xlabel('x-axis');ylabel('y-axis');zlabel('z-axis');

    figure;
    subplot(2,1,1);
    plot(t(ind),psi_exL(ind));
    grid on; title('position error');legend('psi-exL');
    subplot(2,1,2);
    plot(t(ind),psi_evL(ind));
    grid on; title('velocity error');legend('psi-evL');
 
    figure;
    hold on
    for i=round(linspace(1,ind(end),10))
        R_cur=reshape(x(i,7:15),3,3);
        t_cur=x(i,1:3)';
        T_cur=[[R_cur t_cur]; 0 0 0 1];
        trplot(T_cur)
        
    end
    
% % ANIMATION
% % =========
% keyboard;
% animate_3dquad(t(ind), x(ind,:),t(ind), xd(ind,:));


end


