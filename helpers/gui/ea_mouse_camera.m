function [] = ea_mouse_camera(hfig)
% Execute this function to a Figure hfig in order to set camera movements
% to the mouse.
%
% Left click: rotate
% Wheel click / Left click + shift: move
% Right click / Left click + ctrl: zoom


figLastPoint = []; % global variable to store previous cursor position

set(hfig, 'WindowButtonDownFcn', @down_fcn);
set(hfig, 'WindowButtonUpFcn', @up_fcn);


    function [] = down_fcn(hfig, evt)
        
        clickType = evt.Source.SelectionType;
        set(hfig, 'WindowButtonMotionFcn',{@motion_callback,clickType});
        
        % set cursor type
        switch clickType
            case 'normal'
                setptr(gcf, 'rotate');
            case 'extend'
                setptr(gcf, 'hand');
            case 'alt'
                setptr(gcf, 'glass');
            case 'open'
                try
                    set_defaultview;
                end
                
        end
    end
        
        function set_defaultview
            % get stored default view preferences and call ea_defaultview
            prefs = ea_prefs;
            v = prefs.machine.view;
            togglestates = prefs.machine.togglestates;
            ea_defaultview_transition(v,togglestates);
            ea_defaultview(v,togglestates);
        end
        
        
        function [] = motion_callback(hfig, evt, clickType)
            % from matlab's CameraToolBarManager.m
            
            currpt = get(hfig,'CurrentPoint');
            pt = matlab.graphics.interaction.internal.getPointInPixels(hfig,currpt(1:2));
            if isempty(figLastPoint)
                figLastPoint = pt;
            end
            deltaPix  = pt-figLastPoint;
            figLastPoint = pt;
            
            switch clickType
                case 'normal'
                    orbitPangca(deltaPix, 'o');
                case 'extend'
                    dollygca(deltaPix);
                case 'alt'
                    zoomgca(deltaPix);
            end
            
        end
        
        function dollygca(xy)
            % from matlab's CameraToolBarManager.m
            haxes = gca;
            camdolly(haxes,-xy(1), -xy(2), 0, 'movetarget', 'pixels')
            drawnow
        end
        
        function orbitPangca(xy, mode)
            % from matlab's CameraToolBarManager.m
            %mode = 'o';  orbit
            %mode = 'p';  pan
            
            %coordsystem = lower(hObj.coordsys);
            coordsystem = 'z';
            
            haxes = gca;
            
            if coordsystem(1)=='n'
                coordsysval = 0;
            else
                coordsysval = coordsystem(1) - 'x' + 1;
            end
            
            xy = -xy;
            
            if mode=='p' % pan
                panxy = xy*camva(haxes)/500;
            end
            
            if coordsysval>0
                d = [0 0 0];
                d(coordsysval) = 1;
                
                up = camup(haxes);
                upsidedown = (up(coordsysval) < 0);
                if upsidedown
                    xy(1) = -xy(1);
                    d = -d;
                end
                
                % Check if the camera up vector is parallel with the view direction;
                % if not, set the up vector
                if any(matlab.graphics.internal.CameraToolBarManager.crossSimple(d,campos(haxes)-camtarget(haxes)))
                    camup(haxes,d)
                end
            end
            
            flag = 1;
            
            %while sum(abs(xy))> 0 && (flag || hObj.moving) && ishghandle(haxes)
            while sum(abs(xy))> 0 && (flag) && ishghandle(haxes)
                flag = 0;
                if ishghandle(haxes)
                    if mode=='o' %orbit
                        if coordsysval==0 %unconstrained
                            camorbit(haxes,xy(1), xy(2), coordsystem)
                        else
                            camorbit(haxes,xy(1), xy(2), 'data', coordsystem)
                        end
                    else %pan
                        if coordsysval==0 %unconstrained
                            campan(haxes,panxy(1), panxy(2), coordsystem)
                        else
                            campan(haxes,panxy(1), panxy(2), 'data', coordsystem)
                        end
                    end
                    %updateScenelightPosition(hObj,haxes);
                    %localDrawnow(hObj);
                    drawnow
                end
            end
        end
        
        function zoomgca(xy)
            % from matlab's CameraToolBarManager.m
            
            haxes = gca;
            
            q = max(-.9, min(.9, sum(xy)/70));
            q = 1+q;
            
            % heuristic avoids small view angles which will crash on Solaris
            MIN_VIEW_ANGLE = .001;
            MAX_VIEW_ANGLE = 75;
            vaOld = camva(gca);
            camzoom(haxes,q);
            va = camva(haxes);
            %If the act of zooming puts us at an extreme, back the zoom out
            if ~((q>1 || va<MAX_VIEW_ANGLE) && (va>MIN_VIEW_ANGLE))
                set(haxes,'CameraViewAngle',vaOld);
            end
            
            drawnow
        end
        
        function [] = up_fcn(hfig, evt)
            % reset motion and cursor
            set(hfig,'WindowButtonMotionFcn',[]);
            figLastPoint = [];
            setptr(gcf, 'arrow');
        end
        
    end
