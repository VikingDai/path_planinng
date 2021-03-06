function traj=traj(p,t,n,t0,tf)
% firstly, we need mapping betewwn non-dimensionalized and dimensional

t=(t-t0)/(tf-t0);

T=[eye(3)];

for i=1:n
    T=[T t^i*eye(3) ];    
end

Tdx=repmat(zeros(3),1,1);
for i=1:n
    Tdx=[Tdx i*t^(i-1)*eye(3) ];    
end

Td2x=repmat(zeros(3),1,2);
for i=2:n
    Td2x=[Td2x (i-1)*i*t^(i-2)*eye(3)];
end

% this is due to temporal scaling 
traj.x=T*p;
traj.dx=Tdx*p/(tf-t0);
traj.d2x=Td2x*p/(tf-t0)^2;

end