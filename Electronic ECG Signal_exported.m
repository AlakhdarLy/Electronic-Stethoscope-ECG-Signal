classdef projectapp_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        GridLayout           matlab.ui.container.GridLayout
        LeftPanel            matlab.ui.container.Panel
        filterorderDropDown  matlab.ui.control.DropDown
        DropDownLabel        matlab.ui.control.Label
        Lamp                 matlab.ui.control.Lamp
        LampLabel            matlab.ui.control.Label
        StopButton           matlab.ui.control.Button
        StartButton          matlab.ui.control.Button
        RightPanel           matlab.ui.container.Panel
        UIAxes3              matlab.ui.control.UIAxes
        UIAxes2              matlab.ui.control.UIAxes
        UIAxes_2             matlab.ui.control.UIAxes
        UIAxes               matlab.ui.control.UIAxes
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
    end

    
    properties (Access = private)
        AcquiringData logical = false; % Flag to control data acquisition
        a % Arduino connection object
        t % Time vector for plotting
        f % Frequency vector for spectrum
        Fs double = 1000; % Sampling frequency in Hz
        LowCutoff double = 50; % Example low cutoff frequency in Hz
        HighCutoff double = 250; % Example high cutoff frequency in Hz
        FilterOrder double = 2;
    end

    methods (Access = private)

        % Initialize Arduino Connection
        function initializeArduinoConnection(app)
            if isempty(app.a)
                try
                    app.a = arduino('COM4', 'Uno', 'Libraries', 'SPI');
                    disp('Arduino connected successfully.');
                catch e
                    disp('Failed to connect to Arduino:');
                    disp(e.message);
                end
            end
        end

        % Startup Function
        function startupFcn(app)
            initializeArduinoConnection(app);
            app.t = linspace(0, 1, 1000);
            app.f = linspace(0, 500, 500);
            app.Lamp.Color = [1, 0, 0]; % Initialize lamp color to red
        end

        % Update Plots
        function updatePlots(app, rawData)
            plot(app.UIAxes3, app.t, rawData);
            title(app.UIAxes3, 'Raw Signal');
            Y = fft(rawData);
            P2 = abs(Y/length(rawData));
            P1 = P2(1:length(rawData)/2+1);
            P1(2:end-1) = 2*P1(2:end-1);
            plot(app.UIAxes_2, app.f, P1);
            title(app.UIAxes_2, 'Spectrum of Raw Signal');
        end

        
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
  disp('Start button pressed.');
    app.AcquiringData = true;

    % Set the lamp color to green indicating data acquisition is active
    app.Lamp.Color = [0, 1, 0]; 

    % Prepare the Arduino connection and pin, if not already done
    if isempty(app.a)
        app.a = arduino('COM4', 'Uno', 'Libraries', 'SPI');
    end
    signalPin = 'A5';  % Analog pin where the sensor is connected

    % Initialize buffers and variables
    bufferSize = 1000; % Size for the buffer
    voltageBuffer = zeros(1, bufferSize);
    filteredBuffer = zeros(1, bufferSize);
    offsetBuffer = zeros(1, 100);  % For running average
    

    % Initialize variables for plotting
    app.t = linspace(0, 1, bufferSize); % Time vector
    app.f = linspace(0, app.Fs/2, bufferSize/2); % Frequency vector for spectrum

    % Data acquisition and processing loop
    while app.AcquiringData
        % Read new voltage data from the Arduino
        newVoltage = readVoltage(app.a, signalPin);

        % Update the offset buffer and running offset
        offsetBuffer = [offsetBuffer(2:end), newVoltage];
        runningOffset = mean(offsetBuffer);

        % Adjust the new voltage by subtracting the running offset
        adjustedVoltage = newVoltage - runningOffset;

        % Update voltage buffer with adjusted voltage
        voltageBuffer = [voltageBuffer(2:end), adjustedVoltage];

        % Filter Design and Filtering
        
        [filterB, filterA] = butter(app.FilterOrder, [app.LowCutoff, app.HighCutoff] / (app.Fs / 2), 'bandpass');
        filteredVoltage = filter(filterB, filterA, voltageBuffer);
        filteredBuffer = [filteredBuffer(2:end), filteredVoltage(end)];
       
        % Update time vector for plotting
        currentTime = linspace(0, length(voltageBuffer)/app.Fs, length(voltageBuffer));

        % Plot the raw signal
        plot(app.UIAxes3, currentTime, 100*voltageBuffer);
        title(app.UIAxes3, 'Raw Signal');

        % Plot the filtered signal
        plot(app.UIAxes2, currentTime, filteredBuffer);
        title(app.UIAxes2, 'Filtered Signal');

        % Calculate and plot the spectrum of the raw signal
        rawSpectrum = abs(fft(voltageBuffer));
        P1 = rawSpectrum(1:bufferSize/2);
        plot(app.UIAxes_2, app.f, P1);
        title(app.UIAxes_2, 'Spectrum of Raw Signal-FFT');

        % Calculate and plot the spectrum of the filtered signal
        filteredSpectrum = abs(fft(filteredBuffer));
        P1Filtered = filteredSpectrum(1:bufferSize/2);
        plot(app.UIAxes, app.f, P1Filtered);
        title(app.UIAxes, 'Spectrum of Filtered Signal-FFT');

        % Update the GUI
        drawnow;

        % Include a pause for stability and responsiveness
        pause(0.01);
    end

        end

        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
          
            app.AcquiringData = false;
            app.Lamp.Color = [1, 0, 0]; % Set lamp color to red

        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 2x1 grid
                app.GridLayout.RowHeight = {480, 480};
                app.GridLayout.ColumnWidth = {'1x'};
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 1;
            else
                % Change to a 1x2 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {216, '1x'};
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 2;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 880 480];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {216, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create StartButton
            app.StartButton = uibutton(app.LeftPanel, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.BackgroundColor = [0 1 0];
            app.StartButton.Position = [51 380 100 23];
            app.StartButton.Text = 'StartButton';

            % Create StopButton
            app.StopButton = uibutton(app.LeftPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.BackgroundColor = [1 0 0];
            app.StopButton.Position = [51 328 100 23];
            app.StopButton.Text = 'StopButton';

            % Create LampLabel
            app.LampLabel = uilabel(app.LeftPanel);
            app.LampLabel.HorizontalAlignment = 'right';
            app.LampLabel.Position = [35 248 35 22];
            app.LampLabel.Text = 'Lamp';

            % Create Lamp
            app.Lamp = uilamp(app.LeftPanel);
            app.Lamp.Position = [85 237 10 42];

            % Create DropDownLabel
            app.DropDownLabel = uilabel(app.LeftPanel);
            app.DropDownLabel.HorizontalAlignment = 'right';
            app.DropDownLabel.Position = [18 184 65 22];
            app.DropDownLabel.Text = 'Drop Down';

            % Create filterorderDropDown
            app.filterorderDropDown = uidropdown(app.LeftPanel);
            app.filterorderDropDown.Items = {'Order 1', 'Order 2', 'Order 3', 'Order 4', 'Order 5', 'Order 6', 'Order 7', 'Order 8'};
            app.filterorderDropDown.Position = [98 184 100 22];
            app.filterorderDropDown.Value = 'Order 1';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create UIAxes
            app.UIAxes = uiaxes(app.RightPanel);
            title(app.UIAxes, 'FilteredSpectrum Axes-FFT')
            xlabel(app.UIAxes, 'Frequency (Hz)')
            ylabel(app.UIAxes, ' ampulitude')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.XGrid = 'on';
            app.UIAxes.YGrid = 'on';
            app.UIAxes.ColorOrder = [0 0.447058823529412 0.741176470588235;0.850980392156863 0.325490196078431 0.0980392156862745;0.929411764705882 0.694117647058824 0.125490196078431;0.494117647058824 0.184313725490196 0.556862745098039;0.466666666666667 0.674509803921569 0.188235294117647;0.301960784313725 0.745098039215686 0.933333333333333;0.635294117647059 0.0784313725490196 0.184313725490196;1 1 1];
            app.UIAxes.Position = [1 278 300 185];

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.RightPanel);
            title(app.UIAxes_2, 'RawSpectrumAxes-FFT ')
            xlabel(app.UIAxes_2, 'Frequency (Hz)')
            ylabel(app.UIAxes_2, ' Ampulitude')
            zlabel(app.UIAxes_2, 'Z')
            app.UIAxes_2.XGrid = 'on';
            app.UIAxes_2.YGrid = 'on';
            app.UIAxes_2.Position = [8 21 300 185];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.RightPanel);
            title(app.UIAxes2, 'Filtered Signal')
            xlabel(app.UIAxes2, 'Time ')
            ylabel(app.UIAxes2, 'Ampluitde ')
            zlabel(app.UIAxes2, 'Z')
            app.UIAxes2.XGrid = 'on';
            app.UIAxes2.YGrid = 'on';
            app.UIAxes2.Position = [333 278 300 185];

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.RightPanel);
            title(app.UIAxes3, 'Raw Signal ')
            xlabel(app.UIAxes3, 'Time ')
            ylabel(app.UIAxes3, 'Ampluitde ')
            zlabel(app.UIAxes3, 'Z')
            app.UIAxes3.XGrid = 'on';
            app.UIAxes3.YGrid = 'on';
            app.UIAxes3.Position = [333 21 300 185];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = projectapp_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end