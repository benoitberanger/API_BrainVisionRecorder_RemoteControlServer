classdef BVR_RCS < handle
    
    properties(GetAccess=protected, SetAccess=protected)
        recorderip (1,:) char                                              % ex : '192.168.10.11'
        port       (1,1) double                                            % ex : 6700
        timeout    (1,1) double = 1.0;                                     % in seconds
        
        con        (1,1) double = -1
    end % props
    
    
    % methods with no attributes : for set/get methods
    methods
    end % meths
    
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
            assert(nargin==2 && ischar(value) && length(value)>1)
            self.recorderip = value;
        end
        function value = getRecorderIP(self); value = self.recorderip; end
        
        function setPort(self, value)
            assert(nargin==2 && isnumeric(value) && isscalar(value))
            self.port = value;
        end
        function value = getPort(self); value = self.port; end
        
        function setTimeout(self, value)
            assert(nargin==2 && isnumeric(value) && isscalar(value))
            self.timeout = value;
        end
        function value = getTimeout(self); value = self.timeout; end
        
        %------------------------------------------------------------------
        function [statusID, statusMSG] = tcpConnect(self)
            self.log(sprintf('tcpConnect : trying to connect...'))
            
            self.con = pnet('tcpconnect', self.recorderip, self.port);
            pnet(self.con,'setreadtimeout' ,self.timeout);
            pnet(self.con,'setwritetimeout',self.timeout);
            
            [statusID, statusMSG] = self.getStatus();
            if statusID > 0
                self.log(sprintf('tcpConnect : connected to %s:%p', self.recorderip, self.port))
            else
                self.error(sprintf('tcpConnect : not connected'))
            end
        end
        
        %------------------------------------------------------------------
        function [statusID, statusMSG] = getStatus(self, logit)
            if nargin < 2
                logit = false;
            end
            statusID = pnet(self.con,'status');
            statusMSG = self.getStatusMeaning(statusID);
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
        function sendMonitoring(self)
            cmd = 'M';
            ret = 'M:OK';
            
            self.sendMessage(cmd, ret);
        end
        
    end % meths
    
    methods(Access=protected)
        
        function sendMessage(self, cmd, ret)
            
            % write
            self.log(sprintf('sendMessage -> %s', cmd))
            pnet(self.con, 'write', sprintf('%s\r',cmd))
            
            % read
            data = pnet(self.con, 'read', length(ret)+1);
            if strcmp(data(1:end-1), ret)
                self.log(sprintf('sendMessage <- %s', ret))
            else
                self.error(sprintf('sendMessage TIMEOUT'))
            end
            
        end
        
    end % meths
    
    methods(Static)
    end % meths
    
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
            error('[%s - %s]: %s\n', mfilename, datestr(now), msg)
        end
        
    end % meths
    
end % class
