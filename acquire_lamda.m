% FileName = 'SCUC_dat/SCUC6_4period.txt';
FileName = 'SCUC_dat/SCUC30.txt';
SCUC_data = ReadDataSCUC(FileName);
L = 4;

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

% g = 0;
% for i = 1:N
%     mid = 0;
%     for j = 1:N
%         for t =1:T
%            mid = mid - B(i,j) .* y{j}.theta(t); 
%         end
%     end
%     if ismember(i, SCUC_data.units.bus_G)
%         for t =1:T
%             mid = mid + y{i}.PG(t);
%             f_G = f_G + lamda{i}(t)*mid;
%         end
%     end
%     if ismember(i, SCUC_data.busLoad.bus_PDQR)
%         g = g+1;
%         for t = 1:T
%             mid = mid - SCUC_data.busLoad.node_P(t,g);
%             f_G = f_G + lamda{i}(t)*mid;
%         end
%     end
% end

Objective =  f_G;

% options = sdpsettings('verbose',1,'solver','sdpt3','debug',1,'sdpt3.gaptol',1e-5);
options = sdpsettings('solver','cplex','debug',1,'savesolveroutput',1,'savesolverinput',1);
options.showprogress = 1;%1Ϊ������ʾyalmip��������ʲô
options.verbose = 0;%������ʾ��Ϣ�̶ȣ�1Ϊ�ʶ���ʾ��2Ϊ��ȫ��ʾ
options.cplex.exportmodel='abc.lp';

sol = optimize(Constraints,Objective,options);


% Analyze error flags
if sol.problem == 0
    % Extract and display value
    Obj = value(Objective);
    disp(Obj);
    disp(sol.solveroutput.lambda.eqlin(1:N*T));
else
    disp('Oh shit!, something was wrong!');
    sol.info
    yalmiperror(sol.problem)
end