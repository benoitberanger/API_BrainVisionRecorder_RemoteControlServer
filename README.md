# API_BrainVisionRecorder_RemoteControlServer

This repo contains a class to handle communication between MATLAB and **B**rain**V**ision**R**ecorder (BVR) using **R**emote**C**ontrol**S**erver (RCS), typicaly to Start and Stop recording in BVR from MATLAB.

The network communication uses `pnet`, a mex file.
`pnet` can be found here : https://www.mathworks.com/matlabcentral/fileexchange/345-tcp-udp-ip-toolbox-2-0-6'
`pnet` may be bundled with PsychToobox.


# Exemple

```matlab
% create object, and close all previous connections
rc = BVR_RCS();
rc.closeAll()

% set connection IP and port, then connect
rc.setRecorderIP('127.0.0.1')
rc.setPort(6700)
rc.tcpConnect()

% start (or check) that BVR is in Monitoring mode, ready to start record
rc.sendMonitoring()

% up to you if you want to allow or not file overwrite
rc.sendOverwriteOFF()

% output file name will be <ExperimentNumber>_<SubjectID>[.eeg, .vhdr .vmrk]
rc.sendExperimentNumber(date)
rc.sendSubjectID('test_subjectID_rcs')

% lets go ! start the recording
rc.sendStartRecording()
pause(1.0)

% send annotations
rc.sendAnnotation('blank','stim_visual')
pause(0.1)
rc.sendAnnotation('fixation_cross','stim_visual')
pause(0.1)
rc.sendAnnotation('bip','audio_cue')
pause(0.1)
rc.sendAnnotation('fixation_cross','stim_visual')
pause(0.1)
rc.sendAnnotation('blank','stim_visual')
pause(0.1)

% pause and continue
rc.sendPauseRecording()
pause(0.1)
rc.sendContinueRecording()
pause(0.5)

% and now stop recording
rc.sendStopRecording()

% close the connection
rc.closeAll()

```


# Limitations

Some RCS commandes **not** programmed in this API, in particular the comandes whith variable returned message size.


# MATLAB version
Even old versions shoud work, as long as they have object oriented capabilities (R2007 ?)
