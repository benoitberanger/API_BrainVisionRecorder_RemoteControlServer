classdef BVR_RCS < handle
    
    
    %======================================================================
    %======================================================================
    properties(GetAccess=public, SetAccess=protected)
        recorderip (1,:) char                                              % ex : '192.168.10.11'
        port       (1,1) double                                            % ex : 6700
        timeout    (1,1) double = 1.0;                                     % in seconds
        
        con              double = -1
        statusID         double
        statusMSG        char
    end % props
    
    
    %======================================================================
    %======================================================================
    methods(Access=public)
        
        %------------------------------------------------------------------
        % constructor
        function self = BVR_RCS(recorderip, port)
            
            assert(~isempty(which('pnet')), 'pnet not present in matlab path. Download it here : https://www.mathworks.com/matlabcentral/fileexchange/345-tcp-udp-ip-toolbox-2-0-6')
            
            if nargin < 1
                return
            end
            
            self.recorderip = recorderip;
            self.port       = port;
        end
        
        %------------------------------------------------------------------
        % set / get
        function setRecorderIP(self, value)
            assert(nargin==2 && ischar(value) && length(value)>1 && isvector(value),...
                'recorderip must be a char vector')
            self.recorderip = value;
        end
        function value = getRecorderIP(self); value = self.recorderip; end
        
        function setPort(self, value)
            assert(nargin==2 && isnumeric(value) && isscalar(value) && value>0 && value==round(value),...
                'port must be a positive integer')
            self.port = value;
        end
        function value = getPort(self); value = self.port; end
        
        function setTimeout(self, value)
            assert(nargin==2 && isnumeric(value) && isscalar(value) && value>0, 'timeout must be positive')
            self.timeout = value;
        end
        function value = getTimeout(self); value = self.timeout; end
        
        %------------------------------------------------------------------
        function tcpConnect(self)
            self.log(sprintf('tcpConnect : trying to connect to %s:%d...', self.recorderip, self.port))
            
            self.con = pnet('tcpconnect', self.recorderip, self.port);
            pnet(self.con,'setreadtimeout' ,self.timeout);
            pnet(self.con,'setwritetimeout',self.timeout);
            
            self.getStatus();
            if self.statusID > 0
                self.log(sprintf('tcpConnect : connected to %s:%d', self.recorderip, self.port))
            else
                self.log(sprintf('tcpConnect : statusID=%d statusMSG=%s', self.statusID, self.statusMSG))
                self.error(sprintf('tcpConnect : not connected'))
            end
        end
        
        %------------------------------------------------------------------
        function [statusID, statusMSG] = getStatus(self, logit)
            if nargin < 2
                logit = false;
            end
            statusID  = pnet(self.con,'status');
            statusMSG = self.getStatusMeaning(statusID);
            self.statusID  = statusID;
            self.statusMSG = statusMSG;
            if logit
                self.log(sprintf('status = %d : %s', statusID, statusMSG));
            end
        end
        
        %------------------------------------------------------------------
        function closeAll(self)
            pnet('closeall');
            self.log('closeAll : all connection closed');
            self.con = -1;
        end
        
        %------------------------------------------------------------------
        % now all the commands
        
        function sendMonitoring(self)
            self.sendMessage('M');
        end
        
        function sendSubjectID(self, SubjectID)
            assert(nargin==2 && ischar(SubjectID) && length(SubjectID)>1 && isvector(SubjectID),...
                'SubjectID must be a char')
            self.sendMessage(sprintf('3:%s',SubjectID));
        end
        
        function sendExperimentNumber(self, ExperimentNumber)
            assert(nargin==2 && ischar(ExperimentNumber) && length(ExperimentNumber)>1 && isvector(ExperimentNumber),...
                'ExperimentNumber must be a char')
            self.sendMessage(sprintf('2:%s',ExperimentNumber));
        end
        
        function sendStartRecording(self)
            self.sendMessage('S');
            self.waitMessage('RS:4');
        end
        
        function sendStopRecording(self)
            self.sendMessage('Q');
            self.waitMessage('RS:1');
        end
        
        function sendPauseRecording(self)
            self.sendMessage('P');
            self.waitMessage('RS:6');
        end
        
        function sendContinueRecording(self)
            self.sendMessage('C');
            self.waitMessage('RS:4');
        end
        
        function sendOverwriteOFF(self)
            self.sendMessage('OW:0');
        end
        function sendOverwriteON(self)
            self.sendMessage('OW:1');
        end
        
        function sendAnnotation(self, description, type)
            assert(nargin==3 && ischar(description) && length(description)>1 && isvector(description),...
                'description must be a char')
            assert(nargin==3 && ischar(type) && length(type)>1 && isvector(type),...
                'type must be a char')
            self.sendMessage(sprintf('AN:%s;%s',description,type));
        end
        
    end % meths
    
    
    %======================================================================
    %======================================================================
    methods(Access=protected)
        
        %------------------------------------------------------------------
        function sendMessage(self, cmd)
            
            ret = sprintf('%s:OK', cmd);
            
            % write
            self.log(sprintf('sendMessage -> %s', cmd))
            pnet(self.con, 'write', sprintf('%s\r',cmd))
            
            % read
            data = pnet(self.con, 'read', length(ret)+1);
            if strcmp(data(1:end-1), ret)
                self.log(sprintf('sendMessage <- %s', ret))
            else
                self.log(sprintf('!!! last data = %s%s', data,  pnet(self.con, 'read')))
                self.getStatus(true);
                self.error(sprintf('sendMessage ERROR'))
            end
            
        end
        
        %------------------------------------------------------------------
        function waitMessage(self, ret)
            
            self.log(sprintf('waitMessage ? %s', ret))
            
            % read
            data = pnet(self.con, 'read', length(ret)+1);
            if strcmp(data(1:end-1), ret)
                self.log(sprintf('waitMessage <- %s', ret))
            else
                self.log(sprintf('!!! last data = %s%s', data,  pnet(self.con, 'read')))
                self.getStatus(true);
                self.error(sprintf('waitMessage ERROR'))
            end
            
        end
        
    end % meths
    
    
    %======================================================================
    %======================================================================
    methods(Static, Access=protected)
        
        %------------------------------------------------------------------
        function txt = getStatusMeaning(status)
            switch status
                % this come from the .c file
                case -1, txt = 'STATUS_FREE';
                case  0, txt = 'STATUS_NOCONNECT';
                case  1, txt = 'STATUS_TCP_SOCKET';
                case  5, txt = 'STATUS_IO_OK';
                case  6, txt = 'STATUS_UDP_CLIENT';
                case  8, txt = 'STATUS_UDP_SERVER';
                case 10, txt = 'STATUS_CONNECT';
                case 11, txt = 'STATUS_TCP_CLIENT';
                case 12, txt = 'STATUS_TCP_SERVER';
                case 18, txt = 'STATUS_UDP_CLIENT_CONNECT';
                case 19, txt = 'STATUS_UDP_SERVER_CONNECT';
                otherwise, txt = '';
            end
        end
        
        %------------------------------------------------------------------
        % logging
        function log(msg)
            fprintf('[%s - %s]: %s\n', mfilename, datestr(now), msg)
        end
        function error(msg)
            error('[%s - %s]: %s', mfilename, datestr(now), msg)
        end
        
    end % meths
    
end % class
