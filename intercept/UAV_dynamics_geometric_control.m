function [dx, xd,f,M,b1c] = UAV_dynamics_geometric_control(t,x,data)

% Extracing parameters
%%--------------------
% Dynamics of quadrotor suspended with load Constants
mQ = data.params.mQ;
J = data.params.J;
g = data.params.g;
e1 = data.params.e1;
e2 = data.params.e2;
e3 = data.params.e3;
p=data.params.p;
pt=data.params.pt;
traj=get_flats(p,t);
traj_t=get_flats(pt,t);

xQd = traj.x;
vQd = traj.dx;
aQd = traj.d2x;

xQt=traj_t.x;


Omegad = zeros(3,1);

% Extracing states
% ----------------
xQ = x(1:3);
vQ = x(4:6);
R = reshape(x(7:15),3,3);
Omega = x(16:18);
b3 = R(:,3);
dx = [];

    % CONTROL
    % ------
    % Position Control
    eQ = xQ - xQd;
    deQ = vQ - vQd;

    
    k1 =  0.02*diag([4, 4 ,6]);
    k2 = 0.01*diag([3, 3, 4]);
    Fdes = (-k1*eQ - k2*deQ + (mQ)*(aQd + g*e3));
    b3d = Fdes/norm(Fdes);
    f = vec_dot(Fdes,b3); %u1 
    
        
    
    % Attitude Control
    
    
    LOA=xQt-xQ;
    b1c=LOA/norm(LOA);
 
    b2d=vec_cross(b3d,b1c); b2d=b2d/norm(b2d);
    b1d=vec_cross(b2d,b3d);
    Rd = [b1d b2d b3d];
    
    if(norm(Rd'*Rd-eye(3)) > 1e-3)
        disp('Error in R') ; keyboard ;
    end

    kR = 10; kOm = 0.5;
%     kR = 1; kOm = 0.05;
    
    err_R = 1/2 * vee_map(Rd'*R - R'*Rd) ;
    err_Om =Omega -  R'*Rd*Omegad ;
    M = -kR*err_R - kOm*err_Om+ vec_cross(Omega, J*Omega);

    
    % Equations of Motion
    % -------------------
    xQ_dot = vQ;
    vQ_dot = -g*e3 + (f/mQ)*R*e3;    
    R_dot = R*hat_map(Omega) ;
    Omega_dot = (J^-1)*( -vec_cross(Omega, J*Omega) + M ) ;
    
    
% Computing xd
% ------------
xd = [xQd; vQd ];
xd = [xd;reshape(Rd, 9,1);Omegad];

% Computing dx
%-------------
dx = [xQ_dot;
      vQ_dot;
      reshape(R_dot, 9,1) ;
      Omega_dot;];

% if nargout <= 1
%    fprintf('Sim time %0.4f seconds \n',t);
% end
    
end