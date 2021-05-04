%%  DRO_CVaR_ADMM   by yy 2020.12.22

% function [k,time,epsilon]=DRO_CVaR_Alg1(pathAndFilename)

% FileName = 'OPF_DAT/IEEE4.dat';
FileName = 'SCUC_dat/SCUC6_4period.txt';
% FileName = 'SCUC_dat/SCUC30.txt';
SCUC_data = ReadDataSCUC(FileName);
L = 4;

% MonteCarlo_Price(SCUC_data)
load 'lamda_q_6N4Tterminal';

T = SCUC_data.totalLoad.T;  % ʱ����T
G = SCUC_data.units.N;      % �������
N = SCUC_data.baseparameters.busN;  % �ڵ�����

all_branch.I = [ SCUC_data.branch.I; SCUC_data.branchTransformer.I ]; %����֧·��� ǰ��֧·��� ���Ǳ�ѹ��֧·���
all_branch.J = [ SCUC_data.branch.J; SCUC_data.branchTransformer.J ]; %����֧·�յ�
all_branch.P = [ SCUC_data.branch.P; SCUC_data.branchTransformer.P ]; %֧·��������

beta_CVaR = 0.95;

% �γ�ֱ������ϵ������B
type_of_pf = 'DC';
Y = SCUC_nodeY(SCUC_data,type_of_pf);
B = -Y.B; %��Ϊ��ֱ������ ����B�����˵��� ֻ���ǵ翹

% ����һЩ�����õĳ���
diag_E_T = sparse(1:T,1:T,1); %T*T�ĶԽ��󣬶Խ���ȫ1
low_trianle = diag_E_T(2:T,:) - diag_E_T(1:T-1,:); 

% ������� y �� z                            
for i=1:N    % �� �� ����ÿ���ڵ�   
    if ismember(i, SCUC_data.units.bus_G)    % ����Ƿ�����ڵ� ���߱������� ���ʣ���ǣ�����Լ��z
        y{i}.PG = sdpvar(T,1); %sdpvar����ʵ���;��߱���
        y{i}.theta = sdpvar(T,1);
        y{i}.z = sdpvar(T,1);
    else
        y{i}.theta = sdpvar(T,1);
    end
end

for i=1:N    % �� �� ����ÿ���ڵ�   
    if ismember(i, SCUC_data.units.bus_G)    % ����Ƿ�����ڵ� ���߱������� ���ʣ���ǣ�����Լ��z
        z{i}.PG = sdpvar(T,1); %sdpvar����ʵ���;��߱���
        z{i}.theta = sdpvar(T,1);
        z{i}.z = sdpvar(T,1);
    else
        z{i}.theta = sdpvar(T,1);
    end
end
% end of �������

% ������� miu_hat��ֵ�Ĺ���ֵ sigema_hatЭ����Ĺ���ֵ
miu_hat_G_T = zeros(G,T); %ÿ������ÿ��ʱ�ε�۶���ͬ��G*T��
for q = 1:q_line % q_line�����������
    miu_hat_G_T = miu_hat_G_T + reshape(lamda_q_NT(q,:,:),G,T); %��������q�����ۼ� G*T�����͵ĵ��
end
miu_hat_G_T = 1/q_line * miu_hat_G_T;
miu_hat = reshape(miu_hat_G_T',G*T,1); %��ÿ����������ʱ������Ϊ������

% Sigma_hat = sparse(1:G*T,1:G*T,1);
% Sigma_hat = full(Sigma_hat);
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
% tmp = max(lamda_q_NT(:,:,1),[],1); %ȡ��һʱ�Σ���������G����������ֵ
tmp = reshape(tmp,G,T)';
lamda_positive = reshape(tmp, G*T,1);  % ���� lamda��
tmp = min(lamda_q_NT,[],1);
% tmp = min(lamda_q_NT(:,:,1),[],1);
tmp = reshape(tmp,G,T)';
lamda_negative = reshape(tmp, G*T,1);  % ���� lamda��
% end of ����ģ����S

%�����зֺ����з�����
[PI,PINumber,PIG] = portion(N);
D = length(PINumber); %ȷ�����ֿ���

%���ָ��ڵ����ڽڵ㻹����ڵ�
ext = [];
for d = 1:D
    for i = 1:size(all_branch.I,1) %�ӵ�һ��֧·��ʼѭ����������֧·
        left = all_branch.I(i); %֧·�����յ㼴�ɵõ�B����
        right = all_branch.J(i);
        if ismember(left, PI{d}') && ~ismember(right, PI{d}') %�жϸ�֧·�Ƿ����ڵ�ǰ����
            ext = [ext;left;right];
        end
    end
end
ext = unique(ext);
%������������
r = sdpvar(D,1);
t = sdpvar(D,1);
alpha_CVaR = sdpvar(D,1);
z_vector = [];
P_vector = [];
for g = 1:G
    z_vector = [z_vector;  y{SCUC_data.units.bus_G(g)}.z  ];
    P_vector = [P_vector;  y{SCUC_data.units.bus_G(g)}.PG ]; %��������;�ָ�
end

%����ADMM����
u_A_b = [];
rho = 5;
gap_pri = 1e-2;
gap_dual = 1e-2;

M = 100; %��������
% core = D;
% p = parpool(core);
% p.IdleTimeout = 100;
for k = 1:M
    p_A = [];
    z_A = [];
    z_A_pri = [];
    u_A = [];
    p_A_k1 = [];
    u_r = 0; %��Ƿ�����������
    %p-update
    for d = 1:D   
        PIi = PI{d};
        PIN = PINumber{d};
        d_g = PIG{d};
        Constraints = []; %ÿ�ν�Լ�����ÿ�
        miu_hat_d = [];
        lamda_positive_d = [];
        lamda_negative_d = [];
        y_d = [];
        zy_d = [];
        theta_d = [];
        ztheta_d = [];
        z_d = [];
        for i = PIi' %ѭ������ǰƬ���ڵ�
            theta_d = [theta_d;y{i}.theta]; %ȡ��ǰ�������нڵ����
            ztheta_d = [ztheta_d;z{i}.theta]; %ȡ��ǰ�������нڵ����
            
            if ismember(i, SCUC_data.units.bus_G)
                y_d = [y_d;y{i}.PG]; %ȡ��ǰƬ�����е��������
                zy_d = [zy_d;z{i}.PG]; %ȡ��ǰƬ�����е��������
                z_d = [z_d;y{i}.z]; %ȡ��ǰƬ���������
                i_g = find(SCUC_data.units.bus_G == i); %��ǰ����ǵڼ������
                % ����������½�
                Constraints = [Constraints, ...
                    SCUC_data.units.PG_low(i_g) * ones(T,1) <= y{i}.PG <= SCUC_data.units.PG_up(i_g) * ones(T,1)     ];
                
                % ���� Pup��Pdown��� �Ҳ�����P0
                Constraints = [Constraints, ...
                    -SCUC_data.units.ramp(i_g) * ones(T-1,1) <= low_trianle * y{i}.PG <= SCUC_data.units.ramp(i_g) * ones(T-1,1)  ];
                
                % ����������Ի�
                for l = 0:(L-1)
                    p_i_l =SCUC_data.units.PG_low(i_g) +  ( SCUC_data.units.PG_up(i_g) - SCUC_data.units.PG_low(i_g) ) / L * l;
                    Constraints = [Constraints, ...
                        (2* p_i_l * SCUC_data.units.gamma(i_g) +SCUC_data.units.beta(i_g) ) * y{i}.PG - y{i}.z <= (p_i_l^2 * SCUC_data.units.gamma(i_g) - SCUC_data.units.alpha(i_g)) * ones(T,1)  ];
                end  
                
                %���������۾�ֵ
                miu_hat_m = zeros(1,T);
                for q = 1:q_line % q_line�����������
                    miu_hat_m = miu_hat_m + reshape(lamda_q_NT(q,i_g,:),1,T); %��������q�����ۼӵ�i������ĵ��
                end
                miu_hat_m = 1/q_line * miu_hat_m;
                miu_hat_m = reshape(miu_hat_m',T,1); %��ÿ����������ʱ������Ϊ������
                miu_hat_d = [miu_hat_d ; miu_hat_m];
                
                %ȡ��Ӧ��������Сֵ
                lamda_positive_m = lamda_positive(1+T*(i_g-1):T*i_g,1);
                lamda_positive_d = [lamda_positive_d;lamda_positive_m];
                lamda_negative_m = lamda_negative(1+T*(i_g-1):T*i_g,1);
                lamda_negative_d = [lamda_negative_d;lamda_negative_m];
            end 
            
            if ~ismember(i, ext) %�жϽڵ��Ƿ����ڲ��ڵ�
                %��������ڲ���ֱ����������ʽ
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
                Constraints = [Constraints, ...
                    0 <= cons_PF <= b_tmp     ];
                %end of ��������ڲ���֧����������ʽ         
            end
            
            
        end
        
        %�����ڲ���·����Լ��
        for i = 1:size(all_branch.I,1) %�ӵ�һ��֧·��ʼѭ����������֧·
            left = all_branch.I(i); %֧·�����յ㼴�ɵõ�B����
            right = all_branch.J(i);
            if ismember(left,PIi') && ismember(right,PIi') %�жϸ�֧·�Ƿ����ڵ�ǰ����
                abs_x4branch = abs(1/B(left,right));  % ��ǰ֧·���迹�ľ���ֵ |x_ij|
                Constraints = [ Constraints, ...
                    -all_branch.P(i) * abs_x4branch * ones(T,1) <= y{left}.theta - y{right}.theta <= all_branch.P(i) * abs_x4branch * ones(T,1) ];
            end 
        end
        % end of �����ڲ���·����Լ��
        
        %����������Э����
        Sigma_hat_d = zeros(d_g*T,d_g*T);
        for q = 1:q_line
            tmp2 = [];
            for i = PIi'
                if ismember(i, SCUC_data.units.bus_G)
                    i_g = find(SCUC_data.units.bus_G == i); 
                    tmp1 = reshape(lamda_q_NT(q,i_g,:),1*T,1);
                    tmp2 = [tmp2;tmp1];
                end
            end
            tmp2 = tmp2 - miu_hat_d;
            Sigma_hat_d = Sigma_hat_d + tmp2  * tmp2';
        end
        Sigma_hat_d = 1/q_line * Sigma_hat_d;
        Sigma_hat_neg_half = Sigma_hat_d^(-1/2);
     
        %ȡ�ֿ����
        A_d = [sparse(1:T*d_g,1:T*d_g,1); -sparse(1:T*d_g,1:T*d_g,1)];
        B_d = [lamda_positive_d; -lamda_negative_d ];
        
        % �������ģ����
        qline = 500000000;
        deta = 0.3; %����0��1֮����ȡ
        deta_bar = 1 - sqrt(1-deta);
        part1 = abs(Sigma_hat_neg_half * (lamda_positive_d - miu_hat_d ));
        part2 = abs(Sigma_hat_neg_half * (lamda_negative_d - miu_hat_d ));
        part1 = norm(part1);
        part2 = norm(part2);
        R_hat = max(part2, part1);
        
        yy1 = (1 -  ( (R_hat^2 + 2) * (2+sqrt(2*log(4/deta_bar))) / sqrt(qline) )   )^(-1/2);
        R_bar = R_hat * yy1 ;
        
        a_hua_bar = (R_bar^2/sqrt(qline)) * (sqrt(1-G*T/R_bar^4) + sqrt(log(4/deta_bar)));
        b_hua_bar = (R_bar^2/sqrt(qline)) * ( 2+sqrt(2*log(2/deta_bar)) )^2;
        M_hat = max( (R_hat^2 + 2)^2 * (2 + sqrt(2* log(4/deta_bar)))^2  , (8+sqrt(32*log(4/deta_bar)))^2 / (sqrt(R_hat+4) - R_hat)^4 );
        
        gamma_bar_d_1 = b_hua_bar/(1- a_hua_bar - b_hua_bar);
        gamma_bar_d_2 = (1+b_hua_bar)/(1- a_hua_bar - b_hua_bar);
        % end of ����gama

        r_d = r(d);
        t_d = t(d);
        alpha_CVaR_d = alpha_CVaR(d);
        Q_d = sdpvar(d_g*T, d_g*T);
        q_d = sdpvar(d_g*T,1);
        tao1_d = sdpvar(2*d_g*T, 1);
        tao2_d = sdpvar(2*d_g*T, 1);
        p_A_d = [ y_d ; theta_d];
        p_A = [p_A;value(p_A_d)]; %��Ƭ������pk
%         z_A_d = [r_d ; r_d; zy_d ; ztheta_d];
%         z_A = [z_A;(z_A_d)];
%         u_A_d = u_A_0(1 + u_r:(2+d_g*T+PIN*T) + u_r);
%         u_r = u_r + (2+d_g*T+PIN*T);
%         u_A = [u_A;(u_A_d)];
        if k == 1
            z_A_d = zeros(d_g*T+PIN*T,1);
            z_A = [z_A;[ zy_d ; ztheta_d]];
            u_A_d = zeros(d_g*T+PIN*T,1);
            u_A = [u_A;(u_A_d)];
        else
            z_A_d = [ zy_d ; ztheta_d];
            z_A = [z_A;(z_A_d)];
            if d ==1
                u_A_d = u_A_b(1 : (d_g*T+PIN*T));
            elseif d == 2
                 u_A_d = u_A_b(1 +(PIG{1}*T+PINumber{1}*T): (d_g*T+PIN*T)+(PIG{1}*T+PINumber{1}*T));
            else
                u_A_d = u_A_b(1 +((PIG{1}+PIG{2})*T+(PINumber{1}+PINumber{2})*T): (d_g*T+PIN*T)+((PIG{1}+PIG{2})*T+(PINumber{1}+PINumber{2})*T));
            end
            u_A = [u_A;(u_A_d)];
        end
        z_A_pri = [z_A_pri;value(z_A_d)];
        
        % �ο��ڵ�
        Constraints = [Constraints, ...
            y{1}.theta == sparse(T,1)      ];
        % end of �ο��ڵ�
        
        Constraints = [Constraints, tao1_d>=0, tao2_d>=0];  
        Constraints = [Constraints, Q_d>=0];
        Constraints = [Constraints, t_d>= sum(sum(   (gamma_bar_d_2 * Sigma_hat_d + miu_hat_d * miu_hat_d') .* Q_d   )) + miu_hat_d' * q_d + sqrt(gamma_bar_d_1) * norm(Sigma_hat_d^(1/2) * (q_d + 2 * Q_d * miu_hat_d))];
        Constraints = [Constraints, [Q_d, 1/2 * q_d;  1/2 *q_d' , r_d-alpha_CVaR_d] >= -1/2 * [sparse(d_g*T,d_g*T), A_d' * tao1_d;  tao1_d' * A_d,  -2 * tao1_d' * B_d]];
        
        z_d = sum(z_d);
        P_vector_d = y_d;
        Constraints = [Constraints, [Q_d, 1/2 * q_d;  1/2 *q_d' , r_d] + 1 / (1-beta_CVaR) * [sparse(d_g*T,d_g*T), 1/2 * P_vector_d ;  1/2 * P_vector_d' ,beta_CVaR * alpha_CVaR_d - z_d  ] >= -1/2 * [sparse(d_g*T,d_g*T), A_d'* tao2_d;  tao2_d' * A_d,  -2 * tao2_d' * B_d]];
        
        Objective =  r_d + t_d +(rho / 2) * norm(p_A_d - value(z_A_d) + u_A_d)^2;
        options = sdpsettings('verbose',0,'solver','mosek','debug',1);
        sol = optimize(Constraints,Objective,options);
        p_A_k1 = [p_A_k1;p_A_d]; %��Ƭ������pk+1
        % Analyze error flags
        if sol.problem == 0
            % Extract and display value
%             Obj = value(Objective);
%             disp(Obj);
%             disp(sol.solvertime);
        else
            disp('Oh shit!, something was wrong!');
            sol.info
            yalmiperror(sol.problem)
        end
    end
    
    %z-update
    Constraints = [];
    
%     % �ο��ڵ�
%     Constraints = [Constraints, ...
%         z{1}.theta == sparse(T,1)      ];
%     % end of �ο��ڵ�

    % ����֮��Լ������
    for d = 1:D %�������������ι���
        for i = PI{d}' % ����֮���ֱ������Լ��
            if ismember(i,ext)
                cons_PF = sparse(T,1);
                if ismember(i, SCUC_data.units.bus_G) %���i�Ƿ�����ڵ㣬���м���Ӧ�ü���PG
                    cons_PF = cons_PF +  z{i}.PG;
                end
                for j = 1:N
                    cons_PF = cons_PF -B(i,j) .* z{j}.theta;
                end
                
                %�����Ҳ���
                index_loadNode = find(SCUC_data.busLoad.bus_PDQR==i); % �ڵ�i�Ƿ�Ϊ���ɽڵ�
                if index_loadNode>0
                    b_tmp = SCUC_data.busLoad.node_P(:,index_loadNode); %���±�ȡ���ø��ɽڵ㸺��
                else
                    b_tmp = sparse(T,1);
                end
                Constraints = [Constraints, ...
                    0 <= cons_PF <= b_tmp     ]; 
            end
        end
        % end of ����֮���ֱ������Լ��
        
        %����֮����·����Լ��
        for s = 1:size(all_branch.I,1) %�ӵ�һ��֧·��ʼѭ����������֧·
            left = all_branch.I(s); %֧·�����յ㼴�ɵõ�B����
            right = all_branch.J(s);
            if ismember(left, PI{d}') && ~ismember(right, PI{d}') %�жϸ�֧·�Ƿ����ڷ�����
                abs_x4branch = abs(1/B(left,right));  % ��ǰ֧·���迹�ľ���ֵ |x_ij|
                Constraints = [ Constraints, ...
                    -all_branch.P(s) * abs_x4branch * ones(T,1) <= z{left}.theta - z{right}.theta <= all_branch.P(s) * abs_x4branch * ones(T,1) ];
            end
        end
        % end of ����֮����·����Լ��   
    
    end
    

    Objective = (rho / 2) * norm( z_A - value(p_A_k1) - u_A)^2;
    options = sdpsettings('verbose',0,'solver','mosek','debug',1);
    sol = optimize(Constraints,Objective,options);
    % Analyze error flags
    if sol.problem == 0
        % Extract and display value
%         Obj = value(Objective);
%         disp(Obj);
%         disp(sol.solvertime);
    else
        disp('Oh shit!, something was wrong!');
        sol.info
        yalmiperror(sol.problem)
    end
    
    %u-update
    u_A = u_A + (value(p_A_k1) - value(z_A));
    u_A_b = u_A;
    
    %�жϾ���
    pri = p_A - z_A_pri;
    pri = norm(pri);
    dual = rho * ( z_A_pri - z_A );
    dual = norm(value(dual));
    
    if ( pri <= gap_pri) && ( dual <= gap_dual)
        disp('ADMM over');
        break
    end
    msg = sprintf('�� %d ��ѭ��. pri_gap : %d, dual_gap : %d',k,pri,dual);
    disp(msg);
    
end

%���Ŀ�꺯��
obj = r + t;
obj = sum(obj);
disp(value(obj));

%����������
cost = P_vector' * miu_hat - sum(z_vector);
disp(value(cost));
