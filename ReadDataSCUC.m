%% ***************************************************************
%             ���ߣ�ylf
%             ԭ�����ڣ�2017��12��7��
%             �޸����ڣ� 
%             ����˵������SCUC�����ļ���ȡ���������
%% ***************************************************************
%%%  ���ļ�ȡ����  
function SCUC_data=ReadDataSCUC(FileName)
      %% ����˵����******************************************************
% �������˵����FileName�������ļ���
% �������˵����SCUC_data.nodeNum:�ڵ�����  SCUC_data.branchNum:֧·��  standardP����׼����  iterationMax�����������
%centerParameter�����Ĳ���  IterationPrecision���������� objectFunc��Ŀ�꺯������ branchroute ��·�� BalanceI��ƽ��ڵ��  branchI����·ʼ�ڵ�i  branchJ����·�սڵ�j
% branchR����·����  branchX����·�翹  branchB����·�Եص���  branchGroundI���ӵ�֧·�ڵ�i  branchGroundB���ӵ�֧·���� 
% branchTransformerI:��ѹ���ڵ�i  branchTransformerJ����ѹ���ڵ�j  branchTransformerR����ѹ������  branchTransformerX����ѹ���翹
% branchTransformerK����ѹ�����  NodeI�����в����ڵ�i   NodePg:�й�����  NodeQg���޹�����  NodePl���й����� 
% NodeQl:�޹�����  PvI��PV�ڵ�i  PvV:PV�ڵ��ѹ  PvQmin���޹���������  PvQmax���޹���������  
% GenI:������ڵ��  GenC:�������������ϵ��  GenB:��������һ����ϵ��  GenA���������Զ�����ϵ��   
% GenPmin���й���������  GenPmax���й���������  PvNum:Pv�ڵ���  GenNum��������ڵ���
%% ***************************************************************

filedata=fopen(FileName); 

fgetl(filedata);     %���Ե�һ��ע��
%%%  ��ȡ��2������
baseparameters = fscanf(filedata,'%f',[1,7]);
SCUC_data.baseparameters.busN          = baseparameters(1);              %%%  �ڵ�����
SCUC_data.baseparameters.branchN        = baseparameters(2);              %%%  ֧·��
SCUC_data.baseparameters.balanceBus         = baseparameters(3);              %%%  ƽ��ڵ�
SCUC_data.baseparameters.standardP        = baseparameters(4);              %%%  ��׼����
SCUC_data.baseparameters.iterationMax     = baseparameters(5);              %%%  �ڵ㷨����������
SCUC_data.baseparameters.centerParameter  = baseparameters(6);              %%%  ���Ĳ���
SCUC_data.baseparameters.unitN          = baseparameters(7);              %%%  ������
standardP = SCUC_data.baseparameters.standardP;

img1=fgetl(filedata);     %����ע��
img1=fgetl(filedata);     %����ע��

%%%  ��ȡ��������
checkZero = fscanf(filedata,'%d',1);
k=1;
while checkZero~=0
    paraG(k,:) = fscanf(filedata,'%f',[1,16]); %��ȡ���ŷŷ��õ�����
%     paraG(k,:) = fscanf(filedata,'%f',[1,13]); %���ŷ�����
    k=k+1;
    checkZero  = fscanf(filedata,'%d',1);
end
SCUC_data.units.bus_G      = paraG(:,1);
SCUC_data.units.alpha      = paraG(:,2);
SCUC_data.units.beta       = paraG(:,3);
SCUC_data.units.gamma      = paraG(:,4);
SCUC_data.units.PG_up      = paraG(:,5)/standardP;
SCUC_data.units.PG_low     = paraG(:,6)/standardP;
SCUC_data.units.QG_up      = paraG(:,7)/standardP;
SCUC_data.units.QG_low     = paraG(:,8)/standardP;
SCUC_data.units.U_ini      = paraG(:,9);            % ��ʼ��������ʱ�䣿�Ҳ���Ҫ
SCUC_data.units.T_off      = paraG(:,10);           % ��Сͣ��ʱ��
SCUC_data.units.ramp       = paraG(:,12)/standardP; % ����Լ��
SCUC_data.units.start_cost = paraG(:,13);
% SCUC_data.units.a      = paraG(:,16);
% SCUC_data.units.b       = paraG(:,15);
% SCUC_data.units.c      = paraG(:,14); %�ŷ�ϵ����û��ʱ��ע��
SCUC_data.units.N          = k - 1;                 % ������Ŀ


% %%%%%%%%%%%%%%%%%%%%%    Ŀ�꺯��ϵ���س˻�׼ֵ     %%%%%%%%%%%%%%%%%%%%
% beta  = beta*standardP;                                              %
% gamma = gamma*(standardP*standardP);                                 %
SCUC_data.units.alpha = SCUC_data.units.alpha/SCUC_data.baseparameters.standardP;                                             %
SCUC_data.units.gamma = SCUC_data.units.gamma*SCUC_data.baseparameters.standardP;     
% SCUC_data.units.a = SCUC_data.units.a/SCUC_data.baseparameters.standardP; 
% SCUC_data.units.c = SCUC_data.units.c*SCUC_data.baseparameters.standardP; 
%
% %%%%%%%%%%%%%%%%%%%%%    Ŀ�꺯��ϵ���س˻�׼ֵ     %%%%%%%%%%%%%%%%%%%%



%%%  ��ȡ�ڵ��ѹ���½�����
fgetl(filedata);     %����ע��
fgetl(filedata);     %����ע��
checkZero = fscanf(filedata,'%d',1); 
k=1;
while checkZero~=0
    paraV(k,:) = fscanf(filedata,'%f',[1,2]);
    k=k+1;
    checkZero  = fscanf(filedata,'%d',1);
end
SCUC_data.busV.v_up  = paraV(:,1);     %%% �ڵ��ѹ�Ͻ�
SCUC_data.busV.v_low = paraV(:,2);     %%% �ڵ��ѹ�½�

%%%  ��ȡ֧·���� (��������ѹ��֧· )
fgetl(filedata);     %����ע��
fgetl(filedata);     %����ע��
checkZero = fscanf(filedata,'%d',1);
k=1;
while checkZero~=0
    branch(k,:) = fscanf(filedata,'%f',[1,7]);
    k           = k+1;
    checkZero   = fscanf(filedata,'%d',1);
end
SCUC_data.branch.I = branch(:,1);     %%%  ֧·ʼ��
SCUC_data.branch.J = branch(:,2);     %%%  ֧·�յ�
SCUC_data.branch.R = branch(:,4);     %%%  ֧·����
SCUC_data.branch.X = branch(:,5);     %%%  ֧·�翹
SCUC_data.branch.B = branch(:,6);     %%%  ֧·�Եص���  ��Ӧ�����pi�͵�ֵ��·�ĶԵص���
SCUC_data.branch.P = branch(:,7)/standardP;   %%% ֧·���书���Ͻ�

%%%   ��ȡ��ѹ��֧·����
fgetl(filedata);     %����ע��
fgetl(filedata);     %����ע��
checkZero = fscanf(filedata,'%d',1);
k=1;
while checkZero~=0
    branchTransformer(k,:) = fscanf(filedata,'%f',[1,8]);
    k                      = k+1;
    checkZero              = fscanf(filedata,'%d',1);
end
SCUC_data.branchTransformer.I = branchTransformer(:,1);
SCUC_data.branchTransformer.J = branchTransformer(:,2);
SCUC_data.branchTransformer.R = branchTransformer(:,4);
SCUC_data.branchTransformer.X = branchTransformer(:,5);
SCUC_data.branchTransformer.K = 1./branchTransformer(:,8);
SCUC_data.branchTransformer.P = branchTransformer(:,7)/standardP;


%%%  24ʱ�θ������ݼ���ת����
fgetl(filedata);     %����ע��
fgetl(filedata);     %����ע��
checkZero = fscanf(filedata,'%d',1);
k=1;
while checkZero~=0
    load(k,:) = fscanf(filedata,'%f',[1,7]);
    k         = k+1;
    checkZero = fscanf(filedata,'%d',1);
end
SCUC_data.totalLoad.PD_T = load(:,1)/standardP;    %%%  ��ʾ T ʱ�θ���ʱ�ε��ܸ���
SCUC_data.totalLoad.QD_T = load(:,2)/standardP;
R_T  = load(:,5:7)/standardP;
SCUC_data.totalLoad.R_T  = sum(R_T,2);                  %% ���ڸ��ɵĲ�������̫�˽⡣������????   ���Ϊ����������Ϊ���������ת����Լ��
SCUC_data.totalLoad.T = size(SCUC_data.totalLoad.PD_T,1);

%%%  �ڵ㸺������
fgetl(filedata);     %����ע��
fgetl(filedata);     %����ע��
checkZero=fscanf(filedata,'%d',1);
k=1;
while checkZero~=0
    nodeSequence(k) = checkZero;
    nodePQ(k,:)     = fscanf(filedata,'%f',[1,2]);
    k               = k+1;
    checkZero       = fscanf(filedata,'%d',1);
end
SCUC_data.busLoad.bus_PDQR = nodeSequence';
SCUC_data.busLoad.node_P   = nodePQ(:,1)/standardP;
SCUC_data.busLoad.node_Q   = nodePQ(:,2)/standardP;

SCUC_data.busLoad.bus_P_factor = SCUC_data.busLoad.node_P/sum(SCUC_data.busLoad.node_P);  %%%  �ڵ㸺������   �����ڵ�ռ���ɵı�������������������ܸ����з��为�ɡ�
SCUC_data.busLoad.bus_Q_factor = SCUC_data.busLoad.node_Q/sum(SCUC_data.busLoad.node_Q);

SCUC_data.busLoad.node_P = SCUC_data.totalLoad.PD_T * SCUC_data.busLoad.bus_P_factor';
SCUC_data.busLoad.node_Q = SCUC_data.totalLoad.QD_T * SCUC_data.busLoad.bus_Q_factor';

% ��ȡ�ŷ����� 
fgetl(filedata);     %����ע��
fgetl(filedata);     %����ע��
% Emission(1,:)     = fscanf(filedata,'%f',[1,5]);
% SCUC_data.emission.E0 = Emission(1);
% SCUC_data.emission.pi_b = Emission(2);
% SCUC_data.emission.pi_s = Emission(3);
% SCUC_data.emission.deta_E_b_max = Emission(4);
% SCUC_data.emission.deta_E_s_max = min(Emission(5),SCUC_data.emission.E0);


