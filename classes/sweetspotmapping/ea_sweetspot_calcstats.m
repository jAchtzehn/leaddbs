function [vals] = ea_sweetspot_calcstats(obj,patsel,Iperm)

if ~exist('Iperm','var')
    I=obj.responsevar;
else % used in permutation based statistics - in this case the real improvement can be substituted with permuted variables.
    I=Iperm;
end

val = obj.results.efield;

% quickly recalc stats:
if ~exist('patsel','var') % patsel can be supplied directly (in this case, obj.patientselection is ignored), e.g. for cross-validations.
    patsel=obj.patientselection;
end

if size(I,2)==1 % 1 entry per patient, not per electrode
    I=[I,I]; % both sides the same;
end

if obj.mirrorsides
    I=[I;I];
end

if ~isempty(obj.covars)
    for i=1:length(obj.covars)
        if obj.mirrorsides
            covars{i} = [obj.covars{i};obj.covars{i}];
        else
            covars{i} = obj.covars{i};
        end
    end
end

if exist('covars', 'var') % for now take care of covariates by cleaning main variable only.
    I = ea_resid(cell2mat(covars),I);
end

if obj.splitbygroup
    groups=unique(obj.M.patient.group)';
    dogroups=1;
else
    groups=1; % all one, group ignored
    dogroups=0;
end

for group=groups
    gval=val; %refresh fibsval
    if dogroups
        groupspt=find(obj.M.patient.group==group);
        gpatsel=groupspt(ismember(groupspt,patsel));
    else
        gpatsel=patsel;
    end
    if obj.mirrorsides
        gpatsel=[gpatsel,gpatsel+length(obj.allpatients)];
    end
    
    for side=1:numel(gval)
        % check connthreshold
        switch obj.statlevel
            case 'VTAs'
                gval{side}=gval{side}>obj.efieldthreshold; % binarize
            case 'E-Fields'
                gval{side}(gval{side}<obj.efieldthreshold)=nan; % threshold efields
        end
        switch obj.statlevel
            case 'VTAs'
                % get amplitudes
                if isfield(obj.M,'S')
                    for k = 1:length(obj.M.S)
                        amps(k,1) = obj.M.S(k).Rs1.amp;
                        amps(k,2) = obj.M.S(k).Ls1.amp;
                    end
                end
                %get VTA Size
                VTAsize(:,side) = sum(gval{side},2);
                % define null-hypothesis
                switch obj.stat0hypothesis
                    case 'Zero'
                        H0 = 0;
                    case 'Threshold'
                        H0 = obj.statimpthreshold;
                    case 'Average'
                        switch obj.statamplitudecorrection
                            case 'Amplitude (discrete)'
                                keyboard
                            case 'Amplitude (regression)'
                                keyboard
                            case 'Amplitude'
                                H0 = mean(I(gpatsel,side) ./ amps(gpatsel,side));
                            case 'None'
                                H0 = mean(I(gpatsel,side));
                            case 'VTA Size'
                                H0 = mean(I(gpatsel,side) ./ VTAsize(gpatsel,side));
                        end
                end
                switch obj.stattest
                    case 'Mean-Image'
                        thisvals=double(gval{side}(gpatsel,:)).*repmat(I(gpatsel,side),1,size(gval{side}(gpatsel,:),2));
                        Nmap=ea_nansum(double(gval{side}(gpatsel,:)));
                        nanidx=Nmap<round(size(thisvals,1)*(obj.coverthreshold/100));
                        thisvals(:,nanidx)=nan;
                        vals{group,side} = nanmean(thisvals);
                        vals{group,side}(vals{group,side} < obj.statimpthreshold) = NaN;
                    case 'N-Image'
                        tmpind = find(I(gpatsel,side) > obj.statimpthreshold);
                        %                         thisvals=double(gval{side}(tmpind,:)).*repmat(I(tmpind,side),1,size(gval{side}(tmpind,:),2));
                        Nmap=ea_nansum(double(gval{side}(tmpind,:)));
                        vals{group,side} = Nmap;
                        vals{group,side}(vals{group,side} < round(numel(tmpind)*(obj.statNthreshold/100))) = NaN;
                    case 'T-Test'
                        switch obj.statamplitudecorrection
                            case 'Amplitude'
                                I(gpatsel,side) = I(gpatsel,side) ./ amps(gpatsel,side);
                            case 'VTA Size'
                                I(gpatsel,side) = I(gpatsel,side) ./ VTAsize(gpatsel,side);
                        end
                        thisvals=double(gval{side}(gpatsel,:)).*repmat(I(gpatsel,side),1,size(gval{side}(gpatsel,:),2));
                        Nmap=ea_nansum(double(gval{side}(gpatsel,:)));
                        nanidx=Nmap<round(size(thisvals,1)*(obj.coverthreshold/100));
                        thisvals(:,nanidx)=nan;
                        
                        if numel(H0) ~= 1 %in case H0 is different for each setting
                            H0vals = double(gval{side}(gpatsel,:)).*repmat(H0(gpatsel,side),1,size(gval{side}(gpatsel,:),2));
                            [~,ps,~,stats]=ttest(thisvals(:,~nanidx),H0vals(:,~nanidx));
                        else
                            [~,ps,~,stats]=ttest(thisvals(:,~nanidx),H0);
                        end
                        
                        if obj.showsignificantonly
                            stats.tstat=ea_corrsignan(stats.tstat',ps',obj);
                        end
                        vals{group,side}=nan(size(thisvals,2),1);
                        vals{group,side}(~nanidx)=stats.tstat;
                    case 'Wilcoxon-Test'
                        switch obj.statamplitudecorrection
                            case 'Amplitude'
                                I(gpatsel,side) = I(gpatsel,side) ./ amps(gpatsel,side);
                            case 'VTA Size'
                                I(gpatsel,side) = I(gpatsel,side) ./ VTAsize(gpatsel,side);
                        end
                        thisvals=double(gval{side}(gpatsel,:)).*repmat(I(gpatsel,side),1,size(gval{side}(gpatsel,:),2));
                        Nmap=ea_nansum(double(gval{side}(gpatsel,:)));
                        nanidx=Nmap<round(size(thisvals,1)*(obj.coverthreshold/100));
                        thisvals(:,nanidx)=nan;
                        meanvals = nanmean(thisvals,1);                        
                        meanvals = meanvals(~nanidx);
                        tmpvals = thisvals(:,~nanidx);
                        if numel(H0) ~= 1 %in case H0 is different for each setting
                            H0vals = double(gval{side}(gpatsel,:)).*repmat(H0(gpatsel,side),1,size(gval{side}(gpatsel,:),2));
                            H0vals = H0vals(:,~nanidx);
                            for k = 1:length(tmpvals)
                                ps(k)=signrank(tmpvals(:,k),H0vals(:,k));
                            end
                        else
                            for k = 1:length(tmpvals)
                                ps(k)=signrank(tmpvals(:,k),H0);
                            end
                        end
                        
                        if obj.showsignificantonly
                            meanvals=ea_corrsignan(meanvals',ps',obj);
                        end
                        vals{group,side}=nan(size(thisvals,2),1);
                        vals{group,side}(~nanidx)=meanvals;
                end
                %                 switch obj.statconcept
                %                     case 'T-Tests (Normalized Data)'%
                %                         thisvals=double(gval{side}(gpatsel,:)).*repmat(ea_normal(I(gpatsel,side)),1,size(gval{side}(gpatsel,:),2));
                %                         Nmap=ea_nansum(double(gval{side}(gpatsel,:)));
                %                         nanidx=Nmap<round(size(thisvals,1)*(obj.coverthreshold/100));
                %                         thisvals(:,nanidx)=nan;
                %
                %                         [~,ps,~,stats]=ttest(thisvals(:,~nanidx));
                %
                %                         if obj.showsignificantonly
                %                             stats.tstat=ea_corrsignan(stats.tstat',ps',obj);
                %                         end
                %                         vals{group,side}=nan(size(thisvals,2),1);
                %                         vals{group,side}(~nanidx)=stats.tstat;
                %                     otherwise
                %                         keyboard % for Till to fill :)
                %                 end
            case 'E-Fields'
                switch obj.statconcept
                    case 'R-Map'
                        
                        thisvals=gval{side}(gpatsel,:);
                        Nmap=ea_nansum(~isnan(thisvals));
                        
                        nanidx=Nmap<round(size(thisvals,1)*(obj.coverthreshold/100));
                        thisvals=thisvals(:,~nanidx);
                        if obj.showsignificantonly
                            [R,p]=ea_corr(thisvals,I(gpatsel,side),obj.corrtype);
                            R=ea_corrsignan(R,p,obj);
                        else
                            R=ea_corr(thisvals,I(gpatsel,side),obj.corrtype);
                        end
                        
                        vals{group,side}=nan(size(gval{side}(gpatsel,:),2),1);
                        vals{group,side}(~nanidx)=R;
                        
                end
        end
        
    end
    
end



function vals=ea_corrsignan(vals,ps,obj)

nnanidx=~isnan(vals);
numtests=sum(nnanidx);

switch lower(obj.multcompstrategy)
    case 'fdr'
        pnnan=ps(nnanidx);
        [psort,idx]=sort(pnnan);
        pranks=zeros(length(psort),1);
        for rank=1:length(pranks)
            pranks(idx(rank))=rank;
        end
        pnnan=pnnan.*numtests;
        pnnan=pnnan./pranks;
        ps(nnanidx)=pnnan;
    case 'bonferroni'
        ps(nnanidx)=ps(nnanidx).*numtests;
end
ps(~nnanidx)=1;
vals(ps>obj.alphalevel)=nan; % delete everything nonsignificant.
