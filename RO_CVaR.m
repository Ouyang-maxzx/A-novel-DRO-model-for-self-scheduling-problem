%%  DR_CVaR   by yy 2020.11.10

% function [k,time,epsilon]=DRO_CVaR_Alg1(pathAndFilename)

% FileName = 'OPF_DAT/IEEE4.dat';
% FileName = 'SCUC_dat/SCUC6_4period.txt';
% FileName = 'SCUC_dat/SCUC118.txt';
% FileName = 'SCUC_dat/SCUC30.txt';
FileName = 'SCUC_dat/SCUC6.txt';
SCUC_data = ReadDataSCUC(FileName);

% % MonteCarlo_Price(FileName); %Ҫ����lamda_q_NTʱ�ٴ򿪣���Ȼ�˷�ʱ��
% load 'lamda_c_q_NT';
% lamda_q_NT = lamda_c_q_NT;
load 'lamda_q_6N24T';
% load 'lamda_q_30N24T';

T = SCUC_data.totalLoad.T;  % ʱ����T
G = SCUC_data.units.N;      % �������
N = SCUC_data.baseparameters.busN;  % �ڵ�����

all_branch.I = [ SCUC_data.branch.I; SCUC_data.branchTransformer.I ]; %����֧·��� ǰ��֧·��� ���Ǳ�ѹ��֧·���
all_branch.J = [ SCUC_data.branch.J; SCUC_data.branchTransformer.J ]; %����֧·�յ�
all_branch.P = [ SCUC_data.branch.P; SCUC_data.branchTransformer.P ]; %֧·��������

beta_CVaR = 0.99;

% �γ�ֱ������ϵ������B
type_of_pf = 'DC';
Y = SCUC_nodeY(SCUC_data,type_of_pf);
B = -Y.B; %��Ϊ��ֱ������ ����B�����˵��� ֻ���ǵ翹

% ����һЩ�����õĳ���
diag_E_T = sparse(1:T,1:T,1); %T*T�ĶԽ��󣬶Խ���ȫ1
low_trianle = diag_E_T(2:T,:) - diag_E_T(1:T-1,:); 

% �������y                               
for i=1:N    % �� �� ����ÿ���ڵ�   
    if ismember(i, SCUC_data.units.bus_G)    % ����Ƿ�����ڵ� ���߱������� ���ʣ���ǣ�����Լ��z
        y{i}.PG = sdpvar(T,1); %sdpvar����ʵ���;��߱���
        y{i}.theta = sdpvar(T,1);
    else
        y{i}.theta = sdpvar(T,1);
    end
end


cons = [];  % ���е�Լ������

% ���սڵ㿪ʼ��������Լ��
% ֱ����������ʽ ÿ��ѭ������T�в���ʽ���ܵĹ�����N*T������ʽ
for i = 1:N  
    %�����м���
    cons_PF = sparse(T,1); %һ��tһ��Լ�� T��Լ��
    if ismember(i, SCUC_data.units.bus_G) %���i�Ƿ�����ڵ㣬���м���Ӧ�ü���PG
        cons_PF = cons_PF +  y{i}.PG;
    end
    for j = 1:N
        cons_PF = cons_PF -B(i,j) .* y{j}.theta;
%         if ismember(j, SCUC_data.units.bus_G) && j == i   % ����Ƿ�����ڵ� ���ڵĶԽ��Ӿ���λ��
%             cons_PF = cons_PF +  y{j}.PG;
%         end
    end
    
    %�����Ҳ���
    %find�������������±��
    index_loadNode = find(SCUC_data.busLoad.bus_PDQR==i); % �ڵ�i�Ƿ�Ϊ���ɽڵ�
    if index_loadNode>0
        b_tmp = SCUC_data.busLoad.node_P(:,index_loadNode); %���±�ȡ���ø��ɽڵ㸺��
    else
        b_tmp = sparse(T,1);
    end
    cons = [cons, ...
        0 <= cons_PF <= b_tmp     ];
        
end
% end of ֱ����������ʽ


% �ο��ڵ�
%ÿ��ģ�Ͷ�ֻ�趨��һ���ڵ�Ϊ�ο��ڵ㣿
cons = [cons, ...
    y{1}.theta == sparse(T,1)      ];  
% end of �ο��ڵ�


% ��������ڵ�Լ��
for i = 1:G
    bus_index_Gen = SCUC_data.units.bus_G(i);
    % ����������½�
    cons = [cons, ...
        SCUC_data.units.PG_low(i) * ones(T,1) <= y{bus_index_Gen}.PG <= SCUC_data.units.PG_up(i) * ones(T,1)     ];
    
    % ���� Pup��Pdown��� �Ҳ�����P0
    cons = [cons, ...
        -SCUC_data.units.ramp(i) * ones(T-1,1) <= low_trianle * y{bus_index_Gen}.PG <= SCUC_data.units.ramp(i) * ones(T-1,1)  ];
    
%     % ����������Ի�
%     for l = 0:(L-1)
%         p_i_l =SCUC_data.units.PG_low(i) +  ( SCUC_data.units.PG_up(i) - SCUC_data.units.PG_low(i) ) / L * l;
%         cons = [cons, ...
%             (2* p_i_l * SCUC_data.units.gamma(i) +SCUC_data.units.beta(i) ) * y{bus_index_Gen}.PG - y{bus_index_Gen}.z <= (p_i_l^2 * SCUC_data.units.gamma(i) - SCUC_data.units.alpha(i)) * ones(T,1)  ];
%     end
end
% end of ��������ڵ�Լ��


% ����֧·�������Լ��
%��·����Լ��
for i = 1:size(all_branch.I,1) %�ӵ�һ��֧·��ʼѭ����������֧·
    left = all_branch.I(i); %֧·�����յ㼴�ɵõ�B����
    right = all_branch.J(i);
    abs_x4branch = abs(1/B(left,right));  % ��ǰ֧·���迹�ľ���ֵ |x_ij|    
    cons = [ cons, ...
      -all_branch.P(i) * abs_x4branch * ones(T,1) <= y{left}.theta - y{right}.theta <= all_branch.P(i) * abs_x4branch * ones(T,1) ];  
end
% end of ����֧·�������Լ��

% ������� miu_hat��ֵ�Ĺ���ֵ sigema_hatЭ����Ĺ���ֵ
miu_hat_G_T = zeros(G,T); %ÿ������ÿ��ʱ�ε�۶���ͬ��G*T��
for q = 1:q_line % q_line�����������
    miu_hat_G_T = miu_hat_G_T + reshape(lamda_q_NT(q,:,:),G,T); %��������q�����ۼ� G*T�����͵ĵ��
end
miu_hat_G_T = 1/q_line * miu_hat_G_T;
miu_hat = reshape(miu_hat_G_T',G*T,1); %��ÿ����������ʱ������Ϊ������

%�������
t = sdpvar(1);
uk = sdpvar(q_line,T);

Constraints = [];
Constraints = [Constraints,cons]; 

% P_vector = []; %����[p11 p12 ...p1t;p21...p2t...pnt]��������
% cost = 0;
% for g = 1:G
%     P_vector = [P_vector;  y{SCUC_data.units.bus_G(g)}.PG  ]; %��������;�ָ�
%     cost = cost + SCUC_data.units.alpha(g) + SCUC_data.units.beta(g)* y{SCUC_data.units.bus_G(g)}.PG + (SCUC_data.units.gamma(g) * y{SCUC_data.units.bus_G(g)}.PG * y{SCUC_data.units.bus_G(g)}.PG);
% end

% for q = 1:q_line
%     Constraints = [Constraints, uk(q) <= 0 ];
%     lamda_k = reshape(lamda_q_NT(q,:,1),G,1);
%     Constraints = [Constraints, uk(q) <= lamda_k' * P_vector - cost -t]; 
% end

for h = 1:T
    P_vector = []; 
    cost = 0;
    for g = 1:G
        P_vector = [P_vector;  y{SCUC_data.units.bus_G(g)}.PG(h)  ]; %��������;�ָ�
        cost = cost + SCUC_data.units.alpha(g) + SCUC_data.units.beta(g)* y{SCUC_data.units.bus_G(g)}.PG(h) + (SCUC_data.units.gamma(g) * y{SCUC_data.units.bus_G(g)}.PG(h) * y{SCUC_data.units.bus_G(g)}.PG(h));
    end
    
    for q = 1:q_line
        Constraints = [Constraints, uk(q,h) <= 0 ];
        lamda_k = reshape(lamda_q_NT(q,:,h),G,1);
        Constraints = [Constraints, uk(q,h) <= lamda_k' * P_vector - cost -t]; 
    end
end

% W = 0;
% for g = 1:G
%     W = W + (SCUC_data.units.gamma(g) * y{SCUC_data.units.bus_G(g)}.PG * y{SCUC_data.units.bus_G(g)}.PG);
% end
% Constraints = [Constraints, p >= W ]; 

Objective = t + sum(sum(uk)) / ((1 - beta_CVaR) * (q_line));

options = sdpsettings('verbose',1,'solver','mosek','debug',1,'savesolveroutput',1,'savesolverinput',1);
% options.cplex.exportmodel='xyz.lp';

sol = optimize(Constraints,-Objective,options);

% Analyze error flags
if sol.problem == 0
    % Extract and display value
    Obj = value(Objective);

    
%     %������ȷ���
%     for i=1:N  
%         if ismember(i, SCUC_data.units.bus_G) 
%             disp(i);
%             disp(value(y{i}.PG));
%             disp(value(y{i}.theta));
%         else
%             disp(i);
%             disp(value(y{i}.theta));
%         end
%     end

  %����������
    P_vector_re = []; 
    all_cost = 0;
    for g = 1:G
        P_vector_re = [P_vector_re;  y{SCUC_data.units.bus_G(g)}.PG  ]; %��������;�ָ�
        for h = 1:T
            all_cost = all_cost + SCUC_data.units.alpha(g) + SCUC_data.units.beta(g)* y{SCUC_data.units.bus_G(g)}.PG(h) + (SCUC_data.units.gamma(g) * y{SCUC_data.units.bus_G(g)}.PG(h) * y{SCUC_data.units.bus_G(g)}.PG(h));
        end
    end
    profit = miu_hat' * P_vector_re - all_cost;
    disp(value(profit));
    disp(Obj);
    disp(sol.solvertime);
else
    display('Oh shit!, something was wrong!');
    disp(value(t));
    sol.info
    yalmiperror(sol.problem)
end




