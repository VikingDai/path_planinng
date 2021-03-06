classdef problem
    properties
    dim  % dimension of problem 
    range % workspace /size: D x 2 
    obs
    N
    end
    
    methods
        function obj=problem(dim,range,obs,N)
        obj.dim=dim;
        obj.range=range;
        obj.obs=obs;
        obj.N=N;
        end
        
        function mapplot(problem)
            
            axis(reshape(problem.range(1:3,:).',1,[]))
            hold on
            nobs=length(problem.obs);
            for i=1:nobs
                cur_obs=problem.obs{i};
                if problem.dim==2
                    draw_rect([cur_obs(1,1) cur_obs(2,1)],[cur_obs(1,2) cur_obs(2,2)])
                else
                    draw_box([cur_obs(1,1) cur_obs(2,1) cur_obs(3,1)],[cur_obs(1,2) cur_obs(2,2) cur_obs(3,2)])
                end
                
            end
            hold off
            
        end
         
        function isobs=isobs1(problem,x)
            % is a state x in obs?
            nobs=length(problem.obs);            
            isobs=0;
            Npnts=Npoint_gen(x,1.5,problem.N); % 1.5 = length from tip to center 
            for i=1:nobs
                cur_obs=problem.obs{i};
                isobs=isobs || cur_obs.isobs(Npnts); % is modified in Sep 13 
                if isobs==1
                    break
                end                
            end
        end
        
        function isobs=isobs2(problem,x1,x2)
            % are the states along path x1-x2 in obs?
            testnb=5;
            testlist=pnt_gen(x1,x2,testnb);
            isobs=0;

            for j=1:testnb
                isobs=isobs || problem.isobs1(testlist(:,j));
                if isobs==1
                    break
                end
            end
            
        end
        
    end
    
end