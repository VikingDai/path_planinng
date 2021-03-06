%% Demo env

x_obs_set=[3.5,4,4.5,5,5.5 6]/10;
y_obs_set=[4,5]/10;
dx_obs_set=[1,2]/10;
dy_obs_set=[1,2]/10;

inputs=[]; % N_data x N_pixel
outputs=[]; % N_data x N_weight

%% path generation using RRT(*)

dim=2; 
% map setting 


for x_obs=x_obs_set
    for y_obs=y_obs_set
        for dx_obs=dx_obs_set
            for dy_obs=dy_obs_set
                 for repeat=1
                 
fprintf('current iteration - x: %f y: %f dx: %f dy: %f repeat: %d\n',x_obs,y_obs,dx_obs,dy_obs,repeat)
                    

obs=obstacle2(SE2([x_obs y_obs],0),[dx_obs dy_obs]);

ws_range=[0 10;0 10]/10;
prob=problem(dim,ws_range,{obs});

x0=[5 1]'/10;
xf=[5 9]'/10;

g=PGraph(dim);
g.add_node(x0);
g.set_gamma(1);

g_RRT=RRT(prob,g,1000,xf);

p=g_RRT.Astar(1,g.closest(xf));
% g.plot
% g.highlight_path(p)
% for v=p    
%     hold on
% 
%     plot(x0(1),x0(2),'r*')
%     plot(xf(1),xf(2),'r*')    
% end


t0=0; tf=10; N=length(p);

tf=50;
t=linspace(0,tf,N);
pnts=g.vertexlist(:,p);
nbData=100;
tgen=linspace(0,tf,nbData);

[~,xs]=bezier_([t' pnts(1,:)'],500,tgen);
[~,ys]=bezier_([t' pnts(2,:)'],500,tgen);


% plot(xs,ys,'r','LIneWidth',2)

%% Path learning & Reproductionusing DMP 
% learning 
nbVar = 2; %Number of variables (Trajectory in a plane)
nbStates = 6; %Number of states (or primitives) 

K =40; %Initial stiffness gain
D = 10; %Damping gain
dt =0.1; %Time step (need to be changed)

Xs=[xs;ys];
xT=Xs(:,end);

x0=Xs(:,1);
pos_idx=1:nbVar; vel_idx=nbVar+1:2*nbVar; acc_idx=2*nbVar+1:3*nbVar; 
Vs=computeDerivative(Xs,dt);
As=computeDerivative(Vs,dt);
Data=[Xs;Vs;As];

% learning the weight of force term 
s = 1; %Decay term
alpha=1.0;

Mu_d = linspace(nbData,1,nbStates);
% how wide should i spread each function 
Sigma_d = 800;
%Estimate Mu_s and Sigma_s to match Mu_d and Sigma_d

Mu_s(1,:) = exp(-alpha*Mu_d*dt);
for i=1:nbStates
  std_s = Mu_s(1,i) - exp(-alpha*(Mu_d(i)+Sigma_d^.5)*dt);
  Sigma_s(:,:,i) = std_s^2;
end
sList=[];
H=[];
for n=1:nbData
  s = s + (-alpha*s)*dt;    
  sList(n) = s;
  for i=1:nbStates
    h(i) = gaussPDF(s,Mu_s(:,i),Sigma_s(:,:,i));
  end
  %Compute weights
  H(n,:) = h./sum(h)*s;
end

f = inv(K)*(Data(acc_idx,:) - ((repmat(xT,1,nbData)-Data(pos_idx,:))*K - Data(vel_idx,:)*D-K*repmat((xT-x0),1,nbData).*repmat(sList,2,1)));
w = [inv(H'*H)*H'*f']';


% Reproduction
nbRepros=1;
in=[1]; out=[2:3];
for nb=1:nbRepros
  if nb==1
    rWLS(nb).currPos = Data(pos_idx,1); %Initial position
  else
    rWLS(nb).currPos = Data(pos_idx,1) + (rand(2,1)-0.5).*5; %Initial position (with noise)
  end
  x0=rWLS(nb).currPos; 
  rWLS(nb).currVel = zeros(nbVar,1); %Initial velocity
  rWLS(nb).currAcc = zeros(nbVar,1); %Initial acceleration
  s = 1; %Decay term
  for n=1:nbData
    %Log data
    rWLS(nb).Data(:,n) = [rWLS(nb).currPos; rWLS(nb).currVel; rWLS(nb).currAcc];
    %Update s (ds=-alpha*s)
    s = s + (-alpha*s)*dt;
    %Activation weights with WLS
    for i=1:nbStates
      rWLS(nb).H(i,n) = gaussPDF(s,Mu_s(:,i),Sigma_s(:,:,i));
    end
    rWLS(nb).H(:,n) = rWLS(nb).H(:,n) / sum(rWLS(nb).H(:,n));

    %Evaluate acceleration with WLS
    currF0 = (xT-rWLS(nb).currPos)*K - rWLS(nb).currVel*D-K*(xT-x0)*s;
    rWLS(nb).F(:,n) = w * rWLS(nb).H(:,n)*s;
    rWLS(nb).currAcc = currF0 + K*rWLS(nb).F(:,n);

    rWLS(nb).currVel = rWLS(nb).currVel + rWLS(nb).currAcc * dt;
    %Update position 
    rWLS(nb).currPos = rWLS(nb).currPos + rWLS(nb).currVel * dt;
  end
end %nb


%% plot 
% 
% figure
% prob.mapplot()
% 
% g.plot
% g.highlight_path(p)
% 
% plot(xs,ys,'r','LIneWidth',2)
% 
% plot(Data(pos_idx(1),:),Data(pos_idx(2),:),'b*-')



%% Data saving for learning 
Nx=20; Ny=20;
input=reshape(map2pixel(ws_range,{obs},Nx,Ny),1,Nx*Ny);
output=[w(1,:) w(2,:)];
inputs=[inputs ; input];
outputs=[outputs ; output];


                 end
            end
        end
    end
end

% training set / test set 

%%

outputs_norm=outputs-repmat(min(outputs),length(outputs),1);
outputs_norm=outputs./repmat(max(outputs)-min(outputs),length(outputs),1);

csvwrite('input_data.csv', inputs);
csvwrite('output_data.csv', outputs_norm);


