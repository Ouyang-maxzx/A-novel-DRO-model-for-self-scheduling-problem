function MonteCarlo_Price(FileName)
% FileName = 'SCUC_dat/SCUC6_4period.txt';
SCUC_data = ReadDataSCUC(FileName);
L = 4;

% G = size(SCUC_data.busLoad.bus_PDQR,1);
% T = size(SCUC_data.busLoad.node_P,1);
% N = SCUC_data.baseparameters.busN;

T = SCUC_data.totalLoad.T;  % ʱ����T
G = SCUC_data.units.N;      % �������
N = SCUC_data.baseparameters.busN;  % �ڵ�����
all_branch.I = [ SCUC_data.branch.I; SCUC_data.branchTransformer.I ]; %����֧·��� ǰ��֧·��� ���Ǳ�ѹ��֧·���
all_branch.J = [ SCUC_data.branch.J; SCUC_data.branchTransformer.J ]; %����֧·�յ�
all_branch.P = [ SCUC_data.branch.P; SCUC_data.branchTransformer.P ]; %֧·��������

type_of_pf = 'DC';
Y = SCUC_nodeY(SCUC_data,type_of_pf);
B = -Y.B;

% ����һЩ�����õĳ���
diag_E_T = sparse(1:T,1:T,1); %T*T�ĶԽ��󣬶Խ���ȫ1
low_trianle = diag_E_T(2:T,:) - diag_E_T(1:T-1,:); 

cons = [];  % ���е�Լ������
for i=1:N    % �� �� ����ÿ���ڵ�   
    if ismember(i, SCUC_data.units.bus_G)    % ����Ƿ�����ڵ� ���߱������� ���ʣ���ǣ�����Լ��z
        y{i}.PG = sdpvar(T,1); %sdpvar����ʵ���;��߱���
        y{i}.theta = sdpvar(T,1);
        y{i}.z = sdpvar(T,1);
    else
        y{i}.theta = sdpvar(T,1);
    end
end

% ֱ����������ʽ ÿ��ѭ������T�в���ʽ���ܵĹ�����N*T������ʽ
for i = 1:N  
    %�����м���
    cons_PF = sparse(T,1); %һ��tһ��Լ�� T��Լ��
    if ismember(i, SCUC_data.units.bus_G) %���i�Ƿ�����ڵ㣬���м���Ӧ�ü���PG
        cons_PF = cons_PF +  y{i}.PG;
    end
    for j = 1:N
        cons_PF = cons_PF -B(i,j) .* y{j}.theta;
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
      cons_PF - b_tmp == sparse(T,1)   ];
        
end

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

% �ο��ڵ�
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
end
% end of ��������ڵ�Լ��

Constraints = [];
Constraints = [Constraints,cons];

f_G = 0;
g=0;
for i = 1:N
    if ismember(i, SCUC_data.units.bus_G)
        g = g+1;
        for t = 1:T
            f_G = f_G + (SCUC_data.units.alpha(g) + SCUC_data.units.beta(g)*y{i}.PG(t) + SCUC_data.units.gamma(g)*y{i}.PG(t)^2 );
        end
    end
end

Objective =  f_G;

% options = sdpsettings('verbose',1,'solver','sdpt3','debug',1,'sdpt3.gaptol',1e-5);
options = sdpsettings('solver','cplex','debug',1,'savesolveroutput',1,'savesolverinput',1);
options.verbose = 1;%������ʾ��Ϣ�̶ȣ�1Ϊ�ʶ���ʾ��2Ϊ��ȫ��ʾ
options.cplex.exportmodel='abc.lp';

sol = optimize(Constraints,Objective,options);


% % Analyze error flags
% if sol.problem == 0
%     % Extract and display value
%     Obj = value(Objective);
%     disp(Obj);
% else
%     disp('Oh shit!, something was wrong!');
%     sol.info
%     yalmiperror(sol.problem)
% end


%��ʼ�Ŷ�lamda
q_line = 168;

miu_T_0 = -1*sol.solveroutput.lambda.eqlin(1:N*T);
miu_T_0 = reshape(miu_T_0,N,T);
miu_T_1 = zeros(G,T);
j = 1;
for i = 1:N
    if ismember(i, SCUC_data.units.bus_G)
        miu_T_1(j,:) = miu_T_0(i,:);
        j = j+1;
    end
end
% miu_T_0 = 1:T;
% miu_T_1 = miu_T_1 / 10;
miu_T_1 = abs(miu_T_1);
disp(miu_T_1);
PD = zeros(1,T);
std_div_T_0 = zeros(1,T);
% std_div_T_0 = (PD/100-6);
% std_div_T_0(8) = std_div_T_0(8) +9;
% std_div_T_0(9) = std_div_T_0(9) +10;
% std_div_T_0(10) = std_div_T_0(10) +9;
% std_div_T_0(18) = std_div_T_0(18) +7;
% std_div_T_0(19) = std_div_T_0(19) +8;
% std_div_T_0(20) = std_div_T_0(20) +8;
miu_NT = zeros(G,T);
miu_NT_2 = zeros(G,T);
std_div_NT = zeros(G,T);


for i = 1:G
%     miu_NT(i,:) =  miu_T_1(i,:) - SCUC_data.busLoad.node_P(:,i)' * 2; %���ݵľ�ֵ
%     miu_NT_2(i,:) =  miu_T_1(i,:) - SCUC_data.busLoad.node_P(:,i)' * 5;
    miu_NT(i,:) =  miu_T_1(i,:) + 4.24; %���ݵľ�ֵ
    miu_NT_2(i,:) =  miu_T_1(i,:) - 0.235;
%     std_div_NT(i,:) =  std_div_T_0 * 0 +  1  +  randn*0; %���ݵķ���
end


lamda_q_NT = zeros(q_line,G,T);
for i = 1:G
    for t = 1:T
%           lamda_q_NT(:,i,t) = exprnd(miu_T_1(i,t),[q_line,1]); 
        lamda_q_NT(:,i,t) = unifrnd(miu_NT_2(i,t),miu_NT(i,t),[q_line,1]);  %���ȷֲ�
%         lamda_q_NT(:,i,t) = random('norm',miu_NT(i,t),std_div_NT(i,t),[q_line,1]); %��̬�ֲ�
%         lamda_q_NT(:,t) = price_miu(t) * ones(q_line,1);
    end
end
% for i =1:G
%     figure(i);
%     tmp = reshape(lamda_q_NT(:,i,:),q_line,T);
%     plot(tmp');
%     hold on
% end

save('lamda_q_118N24Ttest.mat','lamda_q_NT','q_line');