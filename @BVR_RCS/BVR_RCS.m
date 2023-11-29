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
        
        ui                                                                 % it will contain all UI elements
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
            assert(nargin==3 && ischar(description) && ~isempty(description) && isvector(description),...
                'description must be a char')
            assert(nargin==3 && ischar(type) && ~isempty(type) && isvector(type),...
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


    %======================================================================
    %======================================================================
    methods(Static, Access=public)

        function RC = openGUI(container)

            % Create a fig or use a pre-existing container ----------------

            if ~exist( 'container' , 'var' )

                % Create a figure
                figHandle = figure( ...
                    'MenuBar'         , 'none'                   , ...
                    'Toolbar'         , 'none'                   , ...
                    'Name'            , mfilename                , ...
                    'NumberTitle'     , 'off'                    , ...
                    'Units'           , 'Pixels'                 , ...
                    'Position'        , [100, 100, 700, 300]     , ...
                    'Tag'             , ['fig_' mfilename '_GUI']);

                container = figHandle;
                new_fig = 1;

            else

                figHandle = container;
                new_fig = 0;

            end
            
            % Create instance and store it in the gui data
            RC = BVR_RCS();
            
            RC.ui.container = container;
            
            figureBGcolor = [0.9 0.9 0.9];
            buttonBGcolor = figureBGcolor - 0.1;
            buttonOK      = buttonBGcolor .* [0.8 1.0 0.8];
            buttonKO      = buttonBGcolor .* [1.0 0.8 0.8];
            editBGcolor   = [1.0 1.0 1.0];
            editOK        = editBGcolor.* [0.8 1.0 0.8];
            editKO        = editBGcolor.* [1.0 0.8 0.8];

            if new_fig
                set(figHandle,'Color',figureBGcolor);
            end

            % Create GUI handles : pointers to access the graphic objects
            RC.ui.figureBGcolor = figureBGcolor;
            RC.ui.buttonBGcolor = buttonBGcolor;
            RC.ui.buttonOK      = buttonOK;
            RC.ui.buttonKO      = buttonKO;
            RC.ui.editOK        = editOK;
            RC.ui.editKO        = editKO;

            % Prepare pannels ---------------------------------------------

            RC.ui.panel_setup = uipanel(container, ...
                'Title', 'Setup', ...
                'BackgroundColor',figureBGcolor, ...
                'Units', 'Normalized', ....
                'Position', [0 0 0.5 1] ...
                );

            RC.ui.panel_send = uipanel(container, ...
                'Title', 'Send messages', ...
                'BackgroundColor',figureBGcolor, ...
                'Units', 'normalized', ....
                'Position', [RC.ui.panel_setup.Position(1)+RC.ui.panel_setup.Position(3) 0 1-RC.ui.panel_setup.Position(3) 1] ...
                );

            % Fill setup pannel -------------------------------------------

            RC.ui.edit_ip = uicontrol(RC.ui.panel_setup,...
                'Style','edit',...
                'BackgroundColor',editBGcolor,...
                'Units','normalized',...
                'Position',[0 0.75 0.75 0.25],...
                'String', '127.0.0.1',...
                'Tooltip','IP adress',...
                'Callback', @RC.cb_edit_ip);
            RC.ui.edit_port = uicontrol(RC.ui.panel_setup,...
                'Style','edit',...
                'BackgroundColor',editBGcolor,...
                'Units','normalized',...
                'Position',[0.75 0.75 0.25 0.25],...
                'String', '6700',...
                'Tooltip','port',...
                'Callback',@RC.cb_edit_port);

            RC.ui.pushbutton_connect = uicontrol(RC.ui.panel_setup,...
                'Style','pushbutton',...
                'BackgroundColor',buttonKO,...
                'Units','normalized',...
                'Position',[0 0.5 0.5 0.25],...
                'String', 'Connect',...
                'Tooltip','Open TCP/IP connection using `pnet`',...
                'Callback', @RC.cb_pushbutton_connect);
            RC.ui.pushbutton_close = uicontrol(RC.ui.panel_setup,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0.5 0.5 0.5 0.25],...
                'String', 'Close',...
                'Tooltip','Close TCP/IP connection',...
                'Callback', @RC.cb_pushbutton_close);

            RC.ui.edit_experimentnumber = uicontrol(RC.ui.panel_setup,...
                'Style','edit',...
                'BackgroundColor',editKO,...
                'Units','normalized',...
                'Position',[0 0.25 0.5 0.25],...
                'String', '',...
                'Tooltip','Experiment Number',...
                'Callback', @RC.cb_edit_experimentnumber);
            RC.ui.edit_subjectid = uicontrol(RC.ui.panel_setup,...
                'Style','edit',...
                'BackgroundColor',editKO,...
                'Units','normalized',...
                'Position',[0.5 0.25 0.5 0.25],...
                'String', '',...
                'Tooltip','Subject ID',...
                'Callback', @RC.cb_edit_subjectid);

            RC.ui.pushbutton_overriteON = uicontrol(RC.ui.panel_setup,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0 0 0.5 0.25],...
                'String', 'Overwrite ON',...
                'Tooltip','Allow to overwrite files',...
                'Callback', @RC.cb_pushbutton_overwriteON);
            RC.ui.pushbutton_overriteOFF = uicontrol(RC.ui.panel_setup,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0.5 0 0.5 0.25],...
                'String', 'Overwrite OFF',...
                'Tooltip','Do NOT to allow to overwrite files',...
                'Callback', @RC.cb_pushbutton_overwriteOFF);

            % Fill send pannel --------------------------------------------

            RC.ui.pushbutton_getstatus = uicontrol(RC.ui.panel_send,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0 0.8 1 0.20],...
                'String', 'Get Status',...
                'Tooltip','Get connection status',...
                'Callback', @RC.cb_pushbutton_getstatus);

            RC.ui.pushbutton_monitoring = uicontrol(RC.ui.panel_send,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0 0.6 1 0.2],...
                'String', 'Start/Check monitoring',...
                'Tooltip','Start (or check) that BVR is in Monitoring mode, ready to start record',...
                'Callback', @RC.cb_pushbutton_monitoring);

            RC.ui.pushbutton_startrecording = uicontrol(RC.ui.panel_send,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0 0.4 0.5 0.2],...
                'String', 'Start recording',...
                'Tooltip','',...
                'Callback', @RC.cb_pushbutton_startrecording);
            RC.ui.pushbutton_stoprecording = uicontrol(RC.ui.panel_send,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0.5 0.4 0.5 0.2],...
                'String', 'Stop recording',...
                'Tooltip','',...
                'Callback', @RC.cb_pushbutton_stoprecording);

            RC.ui.pushbutton_pauserecording = uicontrol(RC.ui.panel_send,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0 0.2 0.5 0.2],...
                'String', 'Pause recording',...
                'Tooltip','',...
                'Callback', @RC.cb_pushbutton_pauserecording);
            RC.ui.pushbutton_continuerecording = uicontrol(RC.ui.panel_send,...
                'Style','pushbutton',...
                'BackgroundColor',buttonBGcolor,...
                'Units','normalized',...
                'Position',[0.5 0.2 0.5 0.2],...
                'String', 'Continue recording',...
                'Tooltip','',...
                'Callback', @RC.cb_pushbutton_continuerecording);

            RC.ui.edit_annotation = uicontrol(RC.ui.panel_send,...
                'Style','edit',...
                'BackgroundColor',editBGcolor,...
                'Units','normalized',...
                'Position',[0 0 1 0.25],...
                'String', '',...
                'Tooltip','Annotation : write `description:type` and press ENTER',...
                'Callback', @RC.cb_edit_annotate);

            % End of opening ----------------------------------------------

            % call all callback once to check the default values
            RC.cb_edit_ip(RC.ui.edit_ip)
            RC.cb_edit_port(RC.ui.edit_port)

        end % fcn

    end % meths
    
    %======================================================================
    %======================================================================
    methods(Access=protected)

        %------------------------------------------------------------------
        function cb_edit_ip(self, ui,~)
            new_value = ui.String;
            try
                self.setRecorderIP(new_value)
                ui.BackgroundColor = self.ui.editOK;
            catch ME
                ui.BackgroundColor = self.ui.editKO;
                rethrow(ME)
            end
        end
        function cb_edit_port(self, ui,~)
            new_value = ui.String;
            try
                self.setPort(str2double(new_value))
                ui.BackgroundColor = self.ui.editOK;
            catch ME
                ui.BackgroundColor = self.ui.editKO;
                rethrow(ME)
            end
        end

        %------------------------------------------------------------------
        function cb_pushbutton_connect(self, ui, ~)
            try
                self.tcpConnect();
                ui                      .BackgroundColor = self.ui.buttonOK;
                self.ui.pushbutton_close.BackgroundColor = self.ui.buttonKO;
            catch ME
                ui                      .BackgroundColor = self.ui.buttonKO;
                self.ui.pushbutton_close.BackgroundColor = self.ui.buttonOK;
                rethrow(ME)
            end
        end
        function cb_pushbutton_close(self, ui, ~)
            try
                self.closeAll();
                ui                        .BackgroundColor = self.ui.buttonOK;
                self.ui.pushbutton_connect.BackgroundColor = self.ui.buttonKO;
            catch ME
                ui                        .BackgroundColor = self.ui.buttonKO;
                self.ui.pushbutton_connect.BackgroundColor = self.ui.buttonOK;
                rethrow(ME)
            end
        end

        %------------------------------------------------------------------
        function cb_edit_experimentnumber(self, ui,~)
            new_value = ui.String;
            try
                self.sendExperimentNumber(new_value)
                ui.BackgroundColor = self.ui.editOK;
            catch ME
                ui.BackgroundColor = self.ui.editKO;
                rethrow(ME)
            end
        end
        function cb_edit_subjectid(self, ui,~)
            new_value = ui.String;
            try
                self.sendSubjectID(new_value)
                ui.BackgroundColor = self.ui.editOK;
            catch ME
                ui.BackgroundColor = self.ui.editKO;
                rethrow(ME)
            end
        end

        %------------------------------------------------------------------
        function cb_pushbutton_overwriteON(self, ui, ~)
            try
                self.sendOverwriteON();
                ui                            .BackgroundColor = self.ui.buttonOK;
                self.ui.pushbutton_overriteOFF.BackgroundColor = self.ui.buttonKO;
            catch ME
                ui                            .BackgroundColor = self.ui.buttonKO;
                self.ui.pushbutton_overriteOFF.BackgroundColor = self.ui.buttonKO;
                rethrow(ME)
            end
        end
        function cb_pushbutton_overwriteOFF(self, ui, ~)
            try
                self.sendOverwriteOFF();
                ui                           .BackgroundColor = self.ui.buttonOK;
                self.ui.pushbutton_overriteON.BackgroundColor = self.ui.buttonKO;
            catch ME
                ui                           .BackgroundColor = self.ui.buttonKO;
                self.ui.pushbutton_overriteON.BackgroundColor = self.ui.buttonKO;
                rethrow(ME)
            end
        end

        %------------------------------------------------------------------
        function cb_pushbutton_getstatus(self, ~, ~)
            self.getStatus(true);
        end

        %------------------------------------------------------------------
        function cb_pushbutton_monitoring(self, ~, ~)
            self.sendMonitoring();
        end

        %------------------------------------------------------------------
        function cb_pushbutton_startrecording(self, ~, ~)
            self.sendStartRecording();
        end
        function cb_pushbutton_stoprecording(self, ~, ~)
            self.sendStopRecording();
        end

        %------------------------------------------------------------------
        function cb_pushbutton_pauserecording(self, ~, ~)
            self.sendPauseRecording();
        end
        function cb_pushbutton_continuerecording(self, ~, ~)
            self.sendContinueRecording();
        end

        %------------------------------------------------------------------
        function cb_edit_annotate(self, ui,~)
            split = strsplit(ui.String,':');
            self.sendAnnotation(split{:})
        end

    end % meths

end % class
