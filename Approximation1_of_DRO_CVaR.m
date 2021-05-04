%%  Approximation1_of_DRO_CVaR   by yy 2020.11.12

% function [k,time,epsilon]=DRO_CVaR_Alg1(pathAndFilename)

% FileName = 'OPF_DAT/IEEE4.dat';
% FileName = 'SCUC_dat/SCUC6_4period.txt';
FileName = 'SCUC_dat/SCUC30.txt';
% FileName = 'SCUC_dat/SCUC118.txt';
SCUC_data = ReadDataSCUC(FileName);
L = 4;

% MonteCarlo_Price(FileName);
% load 'lamda_c_q_NT';
% lamda_q_NT = lamda_c_q_NT;
 
load 'lamda_q_30N24T';

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
        y{i}.z = sdpvar(T,1);
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
    
    % ����������Ի�
    for l = 0:(L-1)
        p_i_l =SCUC_data.units.PG_low(i) +  ( SCUC_data.units.PG_up(i) - SCUC_data.units.PG_low(i) ) / L * l;
        cons = [cons, ...
            (2* p_i_l * SCUC_data.units.gamma(i) +SCUC_data.units.beta(i) ) * y{bus_index_Gen}.PG - y{bus_index_Gen}.z <= (p_i_l^2 * SCUC_data.units.gamma(i) - SCUC_data.units.alpha(i)) * ones(T,1)  ];
    end
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


% �������lamda�ľ�ֵmiu_hat ����ֵ��Э����sigema_hat ����ֵ
miu_hat_G_T = zeros(G,T); %ÿ������ÿ��ʱ�ε�۶���ͬ��G*T��
for q = 1:q_line % q_line�����������
    miu_hat_G_T = miu_hat_G_T + reshape(lamda_q_NT(q,:,:),G,T); %��������q�����ۼ� G*T�����͵ĵ��
end
miu_hat_G_T = 1/q_line * miu_hat_G_T;
miu_hat = reshape(miu_hat_G_T',G*T,1); %��ÿ����������ʱ������Ϊ������

Sigma_hat = zeros(G*T,G*T);
for q = 1:q_line
    tmp1 = reshape(lamda_q_NT(q,:,:),G,T) - miu_hat_G_T;
    tmp2 = reshape(tmp1', G*T,1);
    Sigma_hat = Sigma_hat + tmp2  * tmp2';
end
Sigma_hat = 1/q_line * Sigma_hat;
Sigma_hat_neg_half = Sigma_hat^(-1/2);
% end of ��ֵ Э�������

% ����ģ����S G*Tά������������ÿ��G����ʱ������
tmp = max(lamda_q_NT,[],1); %ȡ����ʱ�Σ�����������G����������ֵ
tmp = reshape(tmp,G,T)';
lamda_positive = reshape(tmp, G*T,1);  % ���� lamda��
tmp = min(lamda_q_NT,[],1);
tmp = reshape(tmp,G,T)';
lamda_negative = reshape(tmp, G*T,1);  % ���� lamda��
A = [sparse(1:G*T,1:G*T,1); -sparse(1:G*T,1:G*T,1)];
B = [lamda_positive; -lamda_negative ];
% end of ����ģ����S

% chol(Sigma_hat);

% �����ֽ�
[eig_vector,eig_value] = eig(Sigma_hat);
left_value = (eig_vector * eig_value^(-1/2))';

%����gama
qline = 200000000;
deta = 0.20; %����0��1֮����ȡ
deta_bar = 1 - sqrt(1-deta);

%  R ?=max��(�ˡ�S)?���� ?^(-1?2) (��-�� ? )��
part1 = abs(Sigma_hat_neg_half * (lamda_positive - miu_hat ));
part2 = abs(Sigma_hat_neg_half * (lamda_negative - miu_hat ));
part1 = norm(part1);
part2 = norm(part2);
R_hat = max(part2, part1)/10;    %  R ?=max��(�ˡ�S)?���� ?^(-1?2) (��-�� ? )��

R_bar = R_hat * (1-(R_hat^2 + 2) * ( (2+sqrt(2*log(4/deta_bar))) / sqrt(qline) )   )^(-1/2) ;

a_hua_bar = (R_bar^2/sqrt(qline)) * (sqrt(1-G*T/R_bar^4) + sqrt(log(4/deta_bar)));
b_hua_bar = (R_bar^2/sqrt(qline)) * ( 2+sqrt(2*log(2/deta_bar)) )^2;
M_hat = max( (R_hat^2 + 2)^2 * (2 + sqrt(2* log(4/deta_bar)))^2  , (8+sqrt(32*log(4/deta_bar)))^2 / (sqrt(R_hat+4) - R_hat)^4 );

gamma_bar_1 = b_hua_bar/(1- a_hua_bar - b_hua_bar);
gamma_bar_2 = (1+b_hua_bar)/(1- a_hua_bar - b_hua_bar);
% end of ����gama


%��ʼ�з� ����ά�������������ȡ����ȽϺ�
mi = (G*T)/2; %����ά��
P = (G*T)/mi;%�����зֶ���

%��ʼ�����һ������ģ�ͣ����б�������Ϊ��y(����P,theta, z), alpha,Q,q,r,t,tao1,tao2
%��������
alpha_CVaR = sdpvar(1);
Q = sdpvar(G*T, G*T);
q = sdpvar(G*T,1);
r = sdpvar(1);
t = sdpvar(1);
tao1 = sdpvar(2*G*T, 1);
tao2 = sdpvar(2*G*T, 1);
au_1 = sdpvar(P, 1);
au_2 = sdpvar(P, 1);

%�������������Լ��
Constraints = [];
Constraints = [Constraints, tao1>=0, tao2>=0];  
Constraints = [Constraints,cons];

% I_mi = Sigma_hat((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi);
acce = 0;
for i = 1:P
   I_mi = eye(mi);
   acce = acce + sum(sum( (gamma_bar_2 * I_mi) .* Q((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi) ) );
   Constraints = [Constraints, Q((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi)>=0]; %Q>=0
end
Constraints = [Constraints, t >= acce + sqrt(gamma_bar_1) * norm(q)];
%end of �������������Լ��

%�������Լ��1
for i = 1:P
%     au_1(i) = r - alpha_CVaR - tao1'*B + tao1'* A *miu_hat;
    omg_1 = q(((i-1)*mi+1:i*mi))' + tao1'* A *eig_vector(:,(i-1)*mi+1:i*mi)*(eig_value((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi)^(1/2));
%     Constraints = [Constraints, [Q((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi), 1/2*omg_1'; 1/2*omg_1,au_1(i)] >= 0];
%     Constraints = [Constraints, [Q((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi), 1/2*omg_1'; 1/2*omg_1, - au_1(i)] >= 0];
    Constraints = [Constraints, [Q((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi), 1/2*omg_1'; 1/2*omg_1, au_1(i)] >= 0];
%     au_1_sum = au_1_sum + au_1(i);
end

Constraints = [Constraints, sum(au_1) == r - alpha_CVaR - tao1'*B + tao1'* A *miu_hat ]; 
%end of �������Լ��1

%���ó�������
sum_z = 0;
P_vector = []; %����[p11 p12 ...p1t;p21...p2t...pnt]��������
for g = 1:G
    sum_z = sum_z +sum( y{SCUC_data.units.bus_G(g)}.z );
    P_vector = [P_vector;  y{SCUC_data.units.bus_G(g)}.PG  ]; %��������;�ָ�
end
%end of ���ó�������

% �������Լ��2
for i = 1:P
    omg_21 =  q(((i-1)*mi+1:i*mi))' + tao2'*A*eig_vector(:,(i-1)*mi+1:i*mi)*(eig_value((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi)^(1/2));
    omg_22 =  1 / (1-beta_CVaR) * (P_vector' * eig_vector(:,(i-1)*mi+1:i*mi) * (eig_value((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi)^(1/2))) ;
    omg_2 = omg_21 + omg_22;
%     Constraints = [Constraints, [Q((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi), 1/2*omg_2'; 1/2*omg_2, -au_2(i) ] >= 0];
    Constraints = [Constraints, [Q((i-1)*mi+1:i*mi,(i-1)*mi+1:i*mi), 1/2*omg_2'; 1/2*omg_2, au_2(i) ] >= 0];
%     au_2_sum = au_2_sum + au_2(i);

end

Constraints = [Constraints, sum(au_2) == (r + 1 / (1-beta_CVaR) * (beta_CVaR * alpha_CVaR - sum_z + P_vector'* miu_hat) - tao2' * B + tao2'*A*miu_hat) ]; 
% end of �������Լ��2

Objective =  r + t;
% Objective = sum_z;

% options = sdpsettings('verbose',1,'debug',1,'solver','cplex','savesolveroutput',1,'savesolverinput',1);
% options = sdpsettings('verbose',1,'solver','sdpt3','debug',1,'sdpt3.gaptol',1e-4,'savesolveroutput',1,'savesolverinput',1);
options = sdpsettings('verbose',1,'solver','mosek','debug',1,'savesolveroutput',1,'savesolverinput',1);


% options = sdpsettings('verbose',1,'solver','sdpt3');
sol = optimize(Constraints,Objective,options);


% Analyze error flags
if sol.problem == 0
    % Extract and display value

%     %������ȷ���
%     for i=1:N  
%         if ismember(i, SCUC_data.units.bus_G) 
%             disp(i);
%             disp(value(y{i}.PG));
%             disp(value(y{i}.theta));
%             disp(value(y{i}.z));
%         else
%             disp(i);
%             disp(value(y{i}.theta));
%         end
%     end
    disp(value(Objective));

    %����������
    cost = P_vector' * miu_hat - sum_z;
    disp(value(cost));
    
    disp(sol.solvertime);
        
        
else
    disp('Oh shit!, something was wrong!');
    yalmiperror(sol.problem)
    disp(value(r));
    disp(value(t));
end







