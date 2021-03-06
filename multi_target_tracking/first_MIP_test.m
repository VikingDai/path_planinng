%% problem settings
N = 10; % # of sub-division 
g =[1.5, - 1]'; % position of target 
x0  = [5,5]'; % initial position of tracker 
xl = 0; xu = 6; % lower and upper bound of solution x
yl = 0; yu = 6; % lower and upper bound of solution y

l = norm(g-x0); % length of ray 



%% investigate how many regions were devided and find the index of those
Nk = 0; % number of regions devided 

for k = 1:N
    theta1 = 2*pi/N*(k-1);
    theta2 = 2*pi/N*k;
   
    % two boundary lines
    v1 = [cos(theta1), sin(theta1)]'; 
    v2 = [cos(theta2) , sin(theta2)]'; 
    
    if ( is_in_box(v1,g,[xl xu],[yl yu]) || is_in_box(v2,g,[xl xu],[yl yu]) )
        [A,b] = get_ineq_matrix(g,v1,v2);        
        Nk = Nk +1;
        As{Nk} = A; bs{Nk}=b; % inequality constraint
        ks{Nk}=k; % index of region which intersects with box boundary
    end   
    
end

%% MIP optimization1 - the simplest : picking one point 

A_ineq = [];  x_dim = 2;
M = 1e+4; % big enough
% inequality constraint 
b_ineq = M*ones(2*Nk,1);
for k = 1:Nk    
    A_binary  = zeros(size(As{k},1),Nk);
    A_binary(:,k) = -bs{k} + M*ones(size(As{k},1),1);
    A_cur = [As{k} A_binary];
    A_ineq = [A_ineq ; A_cur];
end

% equality constraint 

A_eq = [zeros(1,x_dim) ones(1,Nk)];
b_eq = [1];

% bound vector 
lb = [xl yl zeros(1,Nk)];
ub = [xu yu ones(1,Nk)];

% example objective function 
f = [1 -1 zeros(1,Nk)]';
intcon = x_dim+1:x_dim+Nk;
sol=intlinprog(f,intcon,A_ineq,b_ineq,A_eq,b_eq,lb,ub);

%% MIP optimization2 - objective function || X - X_ref ||_1 + vis_score(X)

% X_ref = [5 2]'; % 1-norm with this point will be penelized 
X_ref = [1 0.2]'; % 1-norm with this point will be penelized 
A_ineq = [];  x_dim = 2;
M = 1e+4; % big enough
weight = 1;
% arbitrary inverse score map 
vis_score =  weight * fliplr(1:5); % smaller : more visible 

% objective function 
f = [zeros(1,x_dim) vis_score ones(1,2)];

% inequality constraint for sub-division 
b_ineq = [M*ones(2*Nk,1) ; X_ref(1) ; X_ref(2) ; -X_ref(1) ; -X_ref(2)];
for k = 1:Nk    
    A_binary  = zeros(size(As{k},1),Nk);
    A_epi = zeros(size(As{k},1),2); % 2 epi variables are added  
    A_binary(:,k) = -bs{k} + M*ones(size(As{k},1),1);
    A_cur = [As{k} A_binary A_epi];
    A_ineq = [A_ineq ; A_cur];
end

% this insertion of new inequality condition is for epi variables 
A_cur = [eye(2)  zeros(2,Nk) -eye(2) ; -eye(2) zeros(2,Nk) -eye(2)];
A_ineq = [A_ineq ; A_cur];

% equality constraint 

A_eq = [zeros(1,x_dim) ones(1,Nk) zeros(1,2)];
b_eq = [1];

% bound vector 
lb = [xl yl zeros(1,Nk) -inf -inf];
ub = [xu yu ones(1,Nk) inf inf];

% example objective function 
intcon = x_dim+1:x_dim+Nk;
sol=intlinprog(f,intcon,A_ineq,b_ineq,A_eq,b_eq,lb,ub);

%% MIP optimization3  - objective function: || X_3 - X_2|| + || X_2 - X_1|| + || X_1 - X_ref ||+ vis_score(X1) + vis_score(X2) + vis_score(X3) + ... 
H = 3; % future prediction horizon 
vis_score_maps = [4 3 2 1 2 3 4 5 6 7 ; 3 2 1 2 3 4 5 6 7 4; 2 1 2 3 4 5 6 7 4 3];

g0 =[1.5, - 1]'; % position of target 
g1 = g0 + [0.5 0]';
g2 = g1 + [0.5 0]';
gs = [g0 g1 g2];

for t = 1:H
    g = gs(:,t); % current position of the target 
    Nk = 0; % number of regions devided in the time step 
    
    for k = 1:N
        theta1 = 2*pi/N*(k-1);
        theta2 = 2*pi/N*k;

        % two boundary lines
        v1 = [cos(theta1), sin(theta1)]'; 
        v2 = [cos(theta2) , sin(theta2)]'; 

        if ( is_in_box(v1,g,[xl xu],[yl yu]) || is_in_box(v2,g,[xl xu],[yl yu]) )
            [A,b] = get_ineq_matrix(g,v1,v2);        
            Nk = Nk +1;
            As{Nk} = A; bs{Nk}=b; % inequality constraint
            ks{Nk}=k; % index of region which intersects with box boundary
        end   
    end
    As_t{t} = As; bs_t{t}=bs; ks_t{t}=ks;
end











%% plot the problem 

figure 
hold on
axis([min([xl g(1)])-1 max([xu g(1)])+1 min([yl g(2)])-1 max([yu g(1)])+1])
rectangle('Position',[xl yl xu-xl yu-yl],'EdgeColor','k','LineWidth',2)
l_big = 100; % scalar big enough 
plot(x0(1),x0(2),'ko')
plot(g(1),g(2),'ro','MarkerSize',10)

for k = 0:N-1
    theta = 2*pi/N * k;
    plot([g(1) g(1)+l_big*cos(theta)],[g(2) g(2)+l_big*sin(theta)],'LineWidth',1,'Color','k')
end
% inspection point 
plot(X_ref(1),X_ref(2),'b^')
plot(sol(1),sol(2),'r*')
hold off

%% Check the convexity of the problem (the first purple label)

% we will investigate the 3rd region by drawing some surf with mesh grid 
% but its is non convex... 
k = 3;

theta1 = 2*pi/N*(k-1);
theta2 = 2*pi/N*k;


% two boundary lines
s1 = 5; s2 = 4; % assign scores to the lines
v1 = [cos(theta1), sin(theta1)]'; 
v2 =[cos(theta2) , sin(theta2)]'; 

inclusive_point = g + (v1 + v2)/2;

v1_conj = [0 -1; 1 0]*v1; v1_conj = v1_conj / norm(v1_conj); 
v2_conj = [0 1 ; -1 0]*v2; v2_conj = v2_conj / norm(v2_conj);

% now, the distance to each line is d1 =  v1_conj  ' * (x - g), d2 = v2_conj * (x - g)
interp_score = @(x,y) (s1 * v2_conj'*([x,y]' - g) + s2 * v1_conj'*([x,y]' - g) )/(v2_conj'*([x,y]' - g) + v1_conj'*([x,y]' - g));

% generate mesh grid on polar coord 
l_min = 1; l_max = 9; N_l = 40; N_theta = 20;
[r_set, theta_set] = meshgrid(linspace(l_min,l_max,N_l),linspace(theta1,theta2,N_theta));

Xs = g(1) + r_set.* cos(theta_set);
Ys = g(2) + r_set.* sin(theta_set);
Zs = zeros(size(Xs));
hold on 
plot(Xs,Ys,'ko','MarkerSize',1)

for r = 1:N_theta
    for c = 1:N_l
        Zs(r,c) = interp_score(Xs(r),Ys(c));
    end
end

surf(Xs,Ys,Zs)    
colorbar





































