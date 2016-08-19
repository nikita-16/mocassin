! Copyright (C) 2005 Barbara Ercolano 
!
! Version 2005
module output_mod
    use common_mod
    use constants_mod
    use emission_mod
    use photon_mod

    contains


      subroutine outputGas(grid, extMap)
        implicit none

        type(grid_type), intent(inout) :: grid(*) ! the 3D grid
        type(vector) :: aVec, uHat

        character(len=30), optional, intent(in) :: extMap

        ! local variables

        logical                     :: lgInSlit !is this cell within the slit? 

        integer                     :: i,j,k,l,i1d,iG, & ! counters
             & iup,ilow,iLine,lin,elem,ion,n,iCount,iAb,iRes
        integer                     :: nrec              ! counter for rec lines
        integer                     :: abFileUsed
        integer                     :: cellPUsed
        integer                     :: ios               ! I/O error status
        integer                     :: nTau, err, imul
        integer                     :: totLinePackets    ! total number of line packets
        integer                     :: totEscapedPackets ! total number of esc packets


        real, pointer               :: cMap(:)           ! local c-value
        real, pointer               :: flam(:)           ! f(lambda) value from file

        real                        :: dV       ! volume of this cell
        real                        :: factor1  ! calculations factor
        real                        :: factor2  ! calculations factor
        real                        :: g        ! alpha*h*nu (used to calculate line intensities)
        real, pointer               :: HbetaLuminosity(:) ! MC Hbeta luminosity [E36 erg/sec]
        real, pointer               :: HbetaVol(:) ! analytical Hbeta vol em  [E36  erg/sec]        
        real                        :: lr       ! 
        real                        :: LtotAn   ! HbetaVol * sumAn
        real                        :: LtotMC   ! HbetaLuminosity * sumMC 
        real                        :: muLoc    !
        real                        :: sumAn    ! sum of the relative an intensities
        real                        :: sumMC    ! sum of the relative MC intensities
        real                        :: Te10000  ! TeUsed/10000.miser_qinfo -A
        real, parameter             :: hcryd = 2.1799153e-11!
        real                        :: lamS(9)     ! wav in A of singlets
        real                        :: lamT(11)    ! wav in A of triplets

        real, pointer               :: absTau(:), lambda(:)




        ! lexingotn
        !        real, pointer :: denominatorIon(:,:,:) ! denominator for IonVol calculations

        ! Harrington 1982
        real, pointer ::  denominatorIon(:,:)           ! denominator for IonVol calculations
        real, pointer :: denominatorTe(:,:,:)           ! denominator for TeVol calculations

        real, dimension(nLines)             :: &
             &                                       linePacketsUsed ! linePackets at this cell
        real, dimension(nElements) ::  elemAbundanceUsed  ! local abundances
        real, pointer         :: resLinesVol(:,:)    ! resonance lines volume emission
        real, pointer         :: resLinesVolCorr(:,:)! resonance lines volume emissivity corrected 
        real, pointer         :: HIVol(:,:,:)        ! analytical HI rec lines volume emissivity
        real, pointer         :: HeISVol(:,:)        ! analytical HeI singlets volume emissivity
        real, pointer         :: HeITVol(:,:)        ! analytical HeI triplets volume emissivity
        real, pointer         :: HeIIVol(:,:,:)      ! analytical HeII rec lines volume emissivity
        real, pointer         :: ionDenVol(:,:,:)    ! volume av ion abun per H+ particle
        real, pointer         :: lineLuminosity(:,:) ! MC luminosity in a given line

        double precision, dimension(nElements,nstages,nForLevels,nForLevels) :: wav           
        real, pointer         :: forbVol(:,:,:,:,:)  ! analytical forbidden lines volume emissivity
        real, pointer         :: TeVol(:,:,:)      ! mean Temperature for a given ion

        ! recombination lines stuff (1=Oii, 2=mgii,3=neii,4=cii,5=n33ii,6=n34ii)

        real(kind=8), pointer          :: RecLinesFlux(:,:,:)    ! 1st is ion num, 2nd is emissivity
        real(kind=8), dimension(500)   :: recLambdaOII           ! lambda in angstrom
        real(kind=8), dimension(500)   :: recLambdaMgII    
        real(kind=8), dimension(500)   :: recLambdaNeII
        real(kind=8), dimension(500)   :: recLambdaCII
        real(kind=8), dimension(500)   :: recLambdaN33II      !   3-3, Kisielius & Storey 2002
        real(kind=8), dimension(500)   :: recLambdaN34II      !   3d-4f, Escalante & Victor 1990   

        real(kind=8), dimension(500) :: recFlux               ! local rec lines fluxes from subroutine
        real(kind=8), dimension(500) :: recLinesLambda        ! local rec lines wavelengths from subroutine

        real                         :: denIon=0.

        character(len=30), dimension(500) :: recOIIMUL       !multiplet
        character(len=30), dimension(500) :: recOIIlow       !low level
        character(len=30), dimension(500) :: recOIIup        !upper level
        character(len=30), dimension(500) :: recNIItran     !transition for NII


        print*, "in outputGas" 

        ! allocate and initialize arrays and variables

        if (convPercent >= resLinesTransfer .and. lgDust) then
           allocate(resLinesVol(0:nAbComponents, 1:nResLines), stat=err)
           if (err /= 0) then
              print*, "! output mod: can't allocate array resLinesVol memory"
              stop
           end if
           resLinesVol = 0.
           allocate(resLinesVolCorr(0:nAbComponents, 1:nResLines), stat=err)
           if (err /= 0) then
              print*, "! output mod: can't allocate array resLinesVolCorr memory"
              stop
           end if
           resLinesVolCorr = 0.
        end if
        allocate(HIVol(0:nAbComponents, 3:15, 2:8), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array HIVol memory"
           stop
        end if
        allocate(HeISVol(0:nAbComponents, 1:9), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array HeISVol memory"
           stop
        end if
        allocate(HeITVol(0:nAbComponents, 1:11), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array HeITVol memory"
           stop
        end if
        allocate(HeIIVol(0:nAbComponents, 3:30, 2:16), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array HeIIVol memory"
           stop
        end if
        allocate(ionDenVol(0:nAbComponents, 1:nElements, 1:nstages), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array ionDenVol memory"
           stop
        end if
        allocate(forbVol(0:nAbComponents, 1:nElements, 1:nstages, nForLevels,nForLevels), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array forbVol memory"
           stop
        end if
        allocate(TeVol(0:nAbComponents, 1:nElements, 1:nstages), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array TeVol memory"
           stop
        end if
        allocate(recLinesFlux(0:nAbComponents, 1:6, 1:500), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array recLinesFlux memory"
           stop
        end if
        ! Lexington
        !        allocate(denominatorIon(0:nAbComponents, 1:nElements, 1:nstages), stat=err)
        !        if (err /= 0) then
        !           print*, "! output mod: can't allocate array denominatorIon memory"
        !           stop
        !        end if
        ! Harrington
        allocate(denominatorIon(0:nAbComponents, 1:nElements), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array denominatorIon memory"
           stop
        end if
        allocate(denominatorTe(0:nAbComponents, 1:nElements, 1:nstages), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array denominatorTe memory"
           stop
        end if
        allocate(HbetaVol(0:nAbComponents), stat=err)
        if (err /= 0) then
           print*, "! output mod: can't allocate array HbetaVol memory"
           stop
        end if

        if (lgDebug) then
           allocate(lineLuminosity(0:nAbComponents, 1:nLines), stat=err)
           if (err /= 0) then
              print*, "! output mod: can't allocate array lineLuminosity memory"
              stop
           end if
           allocate(HbetaLuminosity(0:nAbComponents), stat=err)
           if (err /= 0) then
              print*, "! output mod: can't allocate array HbetaVol memory"
              stop
           end if
           HbetaLuminosity = 0.
           lineLuminosity  = 0.        
        end if


        denominatorIon  = 0.
        denominatorTe   = 0.
        g               = 0.
        HbetaVol        = 0.
        HIVol           = 0.
        HeISVol         = 0.
        HeITVol         = 0.
        HeIIVol         = 0.
        elemAbundanceUsed = 0.
        ionDenUsed      = 0.
        ionDenVol       = 0.
        LtotAn          = 0.
        LtotMC          = 0.
        wav             = 0.
        forbVol         = 0.
        recLinesLambda  = 0.
        recLambdaOII    = 0.
        recLambdaMgII   = 0.
        recLambdaNeII   = 0.
        recLambdaCII    = 0.
        recLambdan33II  = 0.
        recLambdan34II  = 0.
        recLinesFlux    = 0.
        sumAn           = 0.
        sumMC           = 0.
        TeVol           = 0.
        totLinePackets  = 0
        totEscapedPackets=0          
 
        if (present(extMap)) then 

           if (ngrids>1) then
              print*, '! outputGas: no multiple grids are allowed with extinction maps (yet)'
              print*, 'if this is needed please contact B. Ercolano'
              stop
           end if

           allocate(cMap(0:grid(iG)%nCells), stat=err)
           if (err /= 0) then
              print*, "! output mod: can't allocate array c memory"
              stop
           end if

           cMap=0.

           open(unit=19, status='old', position='rewind', file=extMap, iostat=ios)
           if (ios /= 0) then
              print*, "! outputGas: can't open file for reading, ", extMap
              stop
           end if

           do i = 1, grid(1)%nx
              do j = 1, grid(1)%ny
                 do k = 1, grid(1)%nz         
                    if (grid(1)%active(i,j,k)>0) then
                       read(19, *) l,l,l, cMap(grid(1)%active(i,j,k))
                    else
                       read(19, *) 
                    end if
                 end do
              end do
           end do

           close(19)

           open(unit=20, status='old', position='rewind', file='data/flambda.dat', iostat=ios)
           if (ios /= 0) then
              print*, "! outputGas: can't open file for reading, data/flambda.dat"
              stop
           end if

           read(20,*) l

           allocate(flam(1:l), stat=err)
           if (err /= 0) then
              print*, "! output mod: can't allocate array flam memory"
              stop
           end if

           flam = 0.

           do i = 1, l
              read(20, *) flam(i)
           end do

           close(20)

        end if

        ! calculate analytical emissivities first

        ! sum over all cells
	do iG = 1, nGrids	
           outer: do i = 1, grid(iG)%nx
              do j = 1, grid(iG)%ny
                 do k = 1, grid(iG)%nz

                    ! temporary arrangement
                    if (lg1D ) then
                       if (grid(iG)%ionDen(grid(iG)%active(i,j,k),elementXref(1),1) > 0.95) then 
                          print*, 'R_out = ', grid(iG)%xAxis(i-1), ' (',i-1,')'
                          exit outer
                       end if
                    end if

                    ! slit condition
                    if (dxSlit > 0. .and. dySlit > 0.) then
                       if ( (abs(grid(iG)%xAxis(i))<=dxSlit/2.) .and. &
                            (abs(grid(iG)%yAxis(i))<=dySlit/2.) ) then
                          lgInSlit = .true.
                       else
                          lgInSlit = .false.
                       end if
                    else
                       lgInSlit = .true.
                    end if

                    ! check this cell is in the ionized region
                    if ((grid(iG)%active(i, j, k)>0)) then
                       if (grid(iG)%lgBlack(grid(iG)%active(i,j,k))<1 .and. lgInSlit ) then

                       ! find the physical properties of this cell
                       cellPUsed       = grid(iG)%active(i,j,k)
                       abFileUsed      = grid(iG)%abFileIndex(i,j,k)
                       elemAbundanceUsed(:) = grid(iG)%elemAbun(grid(iG)%abFileIndex(i,j,k), :)
                       HdenUsed        = grid(iG)%Hden(grid(iG)%active(i,j,k))
                       ionDenUsed      = grid(iG)%ionDen(grid(iG)%active(i,j,k), :, :)
                       if (lgDebug) linePacketsUsed = grid(iG)%linePackets(grid(iG)%active(i,j,k), :)
                       NeUsed          = grid(iG)%Ne(grid(iG)%active(i,j,k))
                       TeUsed          = grid(iG)%Te(grid(iG)%active(i,j,k))
                       Te10000         = TeUsed/10000.
                       log10Te         = log10(TeUsed)
                       log10Ne         = log10(NeUsed)
                       sqrTeUsed = sqrt(TeUsed)

                       ! recalculate line emissivities at this cell 

                       ! calculate the emission due to HI and HeI rec lines
                       call RecLinesEmission()

                       ! calculate the emission due to the heavy elements
                       ! forbidden lines
                       call forLines()


                       ! apply extinction correction according to extinction map
                       if (present(extMap)) then

                          if (ngrids>1) then
                             print*, '! outputGas: no multiple grids are allowed with extinction maps (yet)'
                             print*, 'if this is needed please contact be@star.ucl.ac.uk'
                             stop
                          end if

                          iCount = 1

                          ! H recombination lines
                          do iup = 15, 3, -1
                             do ilow = 2, min0(8, iup-1)

                                HIRecLines(iup, ilow) = &
                                     & HIRecLines(iup, ilow)*10.**(-(cMap(grid(1)%active(i,j,k))*flam(iCount)&
                                     & +cMap(grid(1)%active(i,j,k))))
                                iCount = iCount + 1 

                             end do
                          end do

                          ! He I recombination lines
                          ! HeI singlets
                          do l = 1, 9
                             HeIRecLinesS(l) = HeIRecLinesS(l)*10.**& 
                                  & (-(cMap(grid(1)%active(i,j,k))*flam(iCount)+cMap(grid(1)%active(i,j,k))))
                             iCount = iCount + 1
                          end do

                          ! HeI triplets
                          do l = 1, 11
                             HeIRecLinesT(l) = HeIRecLinesT(l)*10.**&
                                  & (-(cMap(grid(1)%active(i,j,k))*flam(iCount)+cMap(grid(1)%active(i,j,k))))
                             iCount = iCount + 1
                          end do

                          ! HeII recombination lines
                          ! HeII rec lines
                          do iup = 3, 30
                             do ilow = 2, min0(16, iup-1)
                                HeIIRecLines(iup,ilow) = HeIIRecLines(iup,ilow)*& 
                                     & 10.**(-(cMap(grid(1)%active(i,j,k))*flam(iCount)+cMap(grid(1)%active(i,j,k))))
                                iCount = iCount + 1
                             end do
                          end do

                          ! collisionally exited lines
                          do elem = 3, nElements
                             do ion = 1, min(elem+1, nstages)
                                if (.not.lgElementOn(elem)) exit

                                if (lgDataAvailable(elem, ion)) then
                                   do iup = 1,nForLevels
                                      do ilow = 1, nForLevels
                                         forbiddenLines(elem,ion,iup,ilow) = &
                                              & forbiddenLines(elem,ion,iup,ilow)*10.**&
                                              & (-(cMap(grid(1)%active(i,j,k))*flam(iCount)+cMap(grid(1)%active(i,j,k))))
                                         iCount = iCount+1
                                      end do
                                   end do
                                end if

                             end do
                          end do

                       end if

                       dV = getVolume(grid(iG), i,j,k)


                       ! Hbeta
                       HbetaVol(abFileUsed) = HbetaVol(abFileUsed) + HIRecLines(4,2)*HdenUsed*dV
                       HbetaVol(0) = HbetaVol(0) + HIRecLines(4,2)*HdenUsed*dV


                       ! HI rec lines
                       do iup = 3, 15
                          do ilow = 2, min0(8,iup-1)
                             HIVol(abFileUsed,iup,ilow) = HIVol(abFileUsed,iup,ilow) + &
                                  & HIRecLines(iup,ilow)*HdenUsed*dV
                             HIVol(0,iup,ilow) = HIVol(0,iup,ilow) + &
                                  & HIRecLines(iup,ilow)*HdenUsed*dV
                          end do
                       end do

                       ! HeI singlets
                       HeISVol(abFileUsed,:) = HeISVol(abFileUsed,:) + HeIRecLinesS(:)*HdenUsed*dV
                       HeISVol(0,:) = HeISVol(0,:) + HeIRecLinesS(:)*HdenUsed*dV


                       ! HeI triplets
                       HeITVol(abFileUsed,:) = HeITVol(abFileUsed,:) + HeIRecLinesT(:)*HdenUsed*dV
                       HeITVol(0,:) = HeITVol(0,:) + HeIRecLinesT(:)*HdenUsed*dV


                       ! HeII rec lines
                       do iup = 3, 30
                          do ilow = 2, min0(16, iup-1)
                             HeIIVol(abFileUsed,iup,ilow) = HeIIVol(abFileUsed,iup,ilow) + &
                                  & HeIIRecLines(iup,ilow)*HdenUsed*dV
                             HeIIVol(0,iup,ilow) = HeIIVol(0,iup,ilow) + &
                                  & HeIIRecLines(iup,ilow)*HdenUsed*dV
                          end do
                       end do

                       ! Heavy elements forbidden lines
                       do elem = 3, nElements
                          do ion = 1, min(elem+1, nstages)                             
                             do iup = 1, nForLevels
                                do ilow = 1, nForLevels
                                   forbVol(abFileUsed,elem,ion,iup,ilow) = &
                                        & forbVol(abFileUsed,elem,ion,iup,ilow) + &
                                        & forbiddenLines(elem,ion,iup,ilow)*HdenUsed*dV
                                   forbVol(0,elem,ion,iup,ilow) = &
                                        & forbVol(0,elem,ion,iup,ilow) + &
                                        & forbiddenLines(elem,ion,iup,ilow)*HdenUsed*dV
                                end do
                             end do
                          end do
                       end do
                       
                       if (lgDust .and. convPercent>resLinesTransfer) then

                          do iRes =1, nResLines

                             do imul = 1, resLine(iRes)%nmul

                                if (resLine(iRes)%elem==1) then
                                   if ( resLine(iRes)%ion == 1 .and. &
                                        &resLine(iRes)%moclow(imul)==1 &
                                        &.and. resLine(iRes)%mochigh(imul)==2 ) then

                                      ! fits to Storey and Hummer MNRAS 272(1995)41
                                      resLinesVol(abFileUsed, iRes) = resLinesVol(abFileUsed, iRes)+&
                                           &  10**(-0.897*log10(TeUsed) + 5.05)* &
                                           & grid(iG)%elemAbun(abFileUsed,1)*ionDenUsed(elementXref(1),2)*&
                                           &  NeUsed*HdenUsed*dV
                                      resLinesVolCorr(abFileUsed, iRes) = resLinesVolCorr(abFileUsed, iRes)+&
                                           &  10**(-0.897*log10(TeUsed) + 5.05)* &
                                           & grid(iG)%elemAbun(abFileUsed,1)*ionDenUsed(elementXref(1),2)*&
                                           &  NeUsed*HdenUsed*dV* (grid(iG)%fEscapeResPhotons(cellPUsed, iRes))
                                      resLinesVol(0, iRes) = resLinesVol(0, iRes)+&
                                           &  10**(-0.897*log10(TeUsed) + 5.05)* &
                                           & grid(iG)%elemAbun(abFileUsed,1)*ionDenUsed(elementXref(1),2)*&
                                           &  NeUsed*HdenUsed*dV
                                      resLinesVolCorr(0, iRes) = resLinesVolCorr(0, iRes)+&
                                           &  10**(-0.897*log10(TeUsed) + 5.05)* grid(iG)%elemAbun(abFileUsed,1)*&
                                           & ionDenUsed(elementXref(1),2)*&
                                           &  NeUsed*HdenUsed*dV* (grid(iG)%fEscapeResPhotons(cellPUsed, iRes))
                                   else
                                      
                                      print*, "! outputGas: [warning] only dust heating from H Lyman &
                                           &alpha and resonance lines from heavy"
                                      print*, "elements is implemented in this version. please contact &
                                           &author B. Ercolano -1-", ires
                                      
                                   end if

                                else if (resLine(iRes)%elem>2) then
                                   
                                   resLinesVol(abFileUsed, iRes) = resLinesVol(abFileUsed, iRes)+&
                                        &forbiddenLines(resLine(iRes)%elem,resLine(iRes)%ion,& 
                                        & resLine(iRes)%moclow(imul),resLine(iRes)%mochigh(imul))*HdenUsed*dV
                                   resLinesVolCorr(abFileUsed, iRes) = resLinesVolCorr(abFileUsed, iRes)+&
                                        &forbiddenLines(resLine(iRes)%elem,resLine(iRes)%ion,& 
                                        & resLine(iRes)%moclow(imul),resLine(iRes)%mochigh(imul))*&
                                        & HdenUsed*dV*(grid(iG)%fEscapeResPhotons(cellPUsed, iRes))
                                   resLinesVol(0, iRes) = resLinesVol(0, iRes)+&
                                        &forbiddenLines(resLine(iRes)%elem,resLine(iRes)%ion,& 
                                        &resLine(iRes)%moclow(imul),resLine(iRes)%mochigh(imul))*HdenUsed*dV
                                   resLinesVolCorr(0, iRes) = resLinesVolCorr(0, iRes)+&
                                        &forbiddenLines(resLine(iRes)%elem,resLine(iRes)%ion,& 
                                        & resLine(iRes)%moclow(imul),resLine(iRes)%mochigh(imul))*&
                                        & HdenUsed*dV*(grid(iG)%fEscapeResPhotons(cellPUsed, iRes))

                                   
                                else
                                   
                                   print*, "! outputGas: [warning] only dust heating from H Lyman &
                                        &alpha and resonance lines from heavy"
                                   print*, "elements is implemented in this version. please & 
                                        &contact author B. Ercolano -2-", ires                                   

                                end if
                                
                             end do
                             
                          end do
                       end if
                       
                       if (lgRecombination) then
                          
                          if (lgElementOn(8)) then
                             denIon = ionDenUsed(elementXref(8),3)*&
                                  & grid(iG)%elemAbun(abFileUsed,8)*HdenUsed
                             
                             recFlux = 0.
                             recLinesLambda = 0.
                             ! rec lines for OII
                             call roii(recLinesLambda, recFlux,TeUsed, NeUsed)
                             
                             do nrec = 1, 500 
                                recLinesFlux(abFileUsed,1,nrec) = recLinesFlux(abFileUsed,1,nrec) + &
                                     &recFlux(nrec)*HIRecLines(4,2)*&
                                     & HdenUsed*dV*&
                                     &ionDenUsed(elementXref(8),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,8)/ionDenUsed(elementXref(1),2)
                                recLinesFlux(0,1,nrec) = recLinesFlux(0,1,nrec) + &
                                     &recFlux(nrec)*HIRecLines(4,2)*&
                                     & HdenUsed*dV*&
                                     &ionDenUsed(elementXref(8),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,8)/ionDenUsed(elementXref(1),2)                               
                             end do
                             recLambdaOII = recLinesLambda
                          end if

                          if (lgElementOn(12)) then                                                     
                             recFlux = 0.
                             recLinesLambda = 0.
                             ! rec lines for MgII 4481
                             call rmgii(recFlux, recLinesLambda, TeUsed)

                             recLinesFlux(abFileUsed,2,:) = recLinesFlux(abFileUsed,2,:) + recFlux*&
                                  &HIRecLines(4,2)*HdenUsed*dV*& 
                                  &ionDenUsed(elementXref(12),3)*&
                                  &grid(iG)%elemAbun(abFileUsed,12)/ionDenUsed(elementXref(1),2)

                             recLinesFlux(0,2,:) = recLinesFlux(0,2,:) + recFlux*&
                                  &HIRecLines(4,2)*HdenUsed*dV*& 
                                  &ionDenUsed(elementXref(12),3)*&
                                  &grid(iG)%elemAbun(abFileUsed,12)/ionDenUsed(elementXref(1),2)

                             recLambdaMgII = recLinesLambda
                          end if

                          if (lgElementOn(10)) then
                             recFlux = 0.
                             recLinesLambda = 0.
                             ! rec lines for NeII
                             call rneii(recLinesLambda, recFlux, TeUsed)

                             do nrec = 1, 500
                                recLinesFlux(abFileUsed,3,nrec) = recLinesFlux(abFileUsed,3,nrec) + recFlux(nrec)*&
                                     &HIRecLines(4,2)*HdenUsed*dV*&
                                     &ionDenUsed(elementXref(10),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,10)/ionDenUsed(elementXref(1),2)
                                recLinesFlux(0,3,nrec) = recLinesFlux(0,3,nrec) + recFlux(nrec)*&
                                     &HIRecLines(4,2)*HdenUsed*dV*&
                                     &ionDenUsed(elementXref(10),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,10)/ionDenUsed(elementXref(1),2)
                             end do
                             recLambdaNeII = recLinesLambda
                          end if

                          if (lgElementOn(6)) then
                             recFlux = 0.
                             recLinesLambda = 0.
                             ! rec lines for CII
                             call rcii(recLinesLambda, recFlux, TeUsed)

                             do nrec = 1, 500
                                recLinesFlux(abFileUsed,4,nrec) = recLinesFlux(abFileUsed,4,nrec) + recFlux(nrec)*&
                                     &HIRecLines(4,2)*HdenUsed*dV*&
                                     &ionDenUsed(elementXref(6),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,6)/ionDenUsed(elementXref(1),2)
                                recLinesFlux(0,4,nrec) = recLinesFlux(0,4,nrec) + recFlux(nrec)*&
                                     &HIRecLines(4,2)*HdenUsed*dV*&
                                     &ionDenUsed(elementXref(6),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,6)/ionDenUsed(elementXref(1),2)
                             end do
                             recLambdaCII = recLinesLambda
                          end if

                          if (lgElementOn(7)) then
                             recFlux = 0.
                             recLinesLambda = 0.
                             denIon = ionDenUsed(elementXref(7),3)*&
                                  & grid(iG)%elemAbun(abFileUsed,7)*HdenUsed

                             ! rec lines for NII 3-3
                             call rnii(recLinesLambda, recFlux, TeUsed, NeUsed)

                             do nrec = 1, 500
                                recLinesFlux(abFileUsed,5,nrec) = recLinesFlux(abFileUsed,5,nrec) + recFlux(nrec)*&
                                     &HIRecLines(4,2)*HdenUsed*dV*&
                                     &ionDenUsed(elementXref(7),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,7)/ionDenUsed(elementXref(1),2)
                                recLinesFlux(0,5,nrec) = recLinesFlux(0,5,nrec) + recFlux(nrec)*&
                                     &HIRecLines(4,2)*HdenUsed*dV*&
                                     &ionDenUsed(elementXref(7),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,7)/ionDenUsed(elementXref(1),2)
                             end do
                             recLambdaN33II = recLinesLambda


                             recFlux = 0.
                             recLinesLambda = 0.

                             ! rec lines for NII 3d-4f
                             call rnii4f(recLinesLambda, recFlux, TeUsed)

                             do nrec = 1, 500
                                recLinesFlux(0,6,nrec) = recLinesFlux(0,6,nrec) + recFlux(nrec)*&
                                     &HIRecLines(4,2)*HdenUsed*dV*&
                                     &ionDenUsed(elementXref(7),3)*&
                                     &grid(iG)%elemAbun(abFileUsed,7)/ionDenUsed(elementXref(1),2)
                             end do
                             recLambdaN34II = recLinesLambda
                          end if

                       end if


                       ! calculate line packets luminosities
                       ! first of all sum over all the cells                    
                       if (lgDebug) then
                          do l = 1, nLines
                             lineLuminosity(abFileUsed,l) = lineLuminosity(abFileUsed,l) + linePacketsUsed(l)
                             lineLuminosity(0,l) = lineLuminosity(0,l) + linePacketsUsed(l)                            
                             totLinePackets    = totLinePackets + linePacketsUsed(l)
                          end do

                          ! calculate the total number of escaped packets
                          do l = 1, nbins
                             totEscapedPackets = totEscapedPackets + &
                                  & grid(iG)%escapedPackets(grid(iG)%active(i,j,k),l,0)
                          end do

                          ! MC estimator of Hbeta luminosity
                          HbetaLuminosity(abFileUsed) = lineLuminosity(abFileUsed,2)
                          HbetaLuminosity(0) = lineLuminosity(0,2)

                       end if

                       ! calculate mean temperatures for the ions
                       ! and the mean <ion>/<H+> 
                       factor1 = TeUsed*NeUsed*HdenUsed*dV
                       factor2 = NeUsed*HdenUsed*dV

                       do elem = 1, nElements
                          do ion = 1, min(elem+1,nstages)
                             if (.not.lgElementOn(elem)) exit

                             TeVol(abFileUsed,elem,ion) = TeVol(abFileUsed,elem,ion) + &
                                  & ionDenUsed(elementXref(elem),ion)*factor1

                             denominatorTe(abFileUsed,elem,ion) = denominatorTe(abFileUsed,elem,ion) + &
                                  & ionDenUsed(elementXref(elem),ion)*factor2


                             ionDenVol(abFileUsed,elem,ion) = ionDenVol(abFileUsed,elem,ion)+ &
                                  & ionDenUsed(elementXref(elem),ion)*factor2


                             ! this is the definition used in the lexington benchmark 
!                                denominatorIon(abFileUsed,elem,ion) = denominatorIon(abFileUsed,elem,ion) + &
!                                     & ionDenUsed(elementXref(1),2)*factor2

                             TeVol(0,elem,ion) = TeVol(0,elem,ion) + &
                                  & ionDenUsed(elementXref(elem),ion)*factor1

                             denominatorTe(0,elem,ion) = denominatorTe(0,elem,ion) + &
                                  & ionDenUsed(elementXref(elem),ion)*factor2


                             ionDenVol(0,elem,ion) = ionDenVol(0,elem,ion)+ &
                                  & ionDenUsed(elementXref(elem),ion)*factor2


                             ! this is the definition used in the lexington benchmark 
!                                denominatorIon(0,elem,ion) = denominatorIon(0,elem,ion) + &
!                                     & ionDenUsed(elementXref(1),2)*factor2


                          end do
                       end do

                    end if
                    end if

                 end do
              end do
           end do outer

        end do

        ! the following is the definition given by Harrington et al. 1982

        do iAb = 0, nAbComponents

           ! reinitialize sumAm and sumMC
           sumAn = 0.
           sumMC = 0.

           do elem = 1, nElements
              do ion = 1, min(elem+1, nstages)
                 denominatorIon(iAb,elem) = denominatorIon(iAb,elem) + ionDenVol(iAb,elem,ion)

              end do
           end do


           do elem = 1, nElements
              do ion = 1, min(elem+1, nstages)
                 if (.not.lgElementOn(elem)) exit

                 if (denominatorTe(iAb,elem,ion) <= 0.) then
                    TeVol(iAb,elem,ion) = 0.
                 else
                    TeVol(iAb,elem,ion) = TeVol(iAb,elem,ion) / denominatorTe(iAb,elem,ion)
                 end if

                 ! lexington benchmark

!                 if (denominatorIon(iAb,elem,ion) <= 0.) then
!                    ionDenVol(iAb,elem,ion) = 0.
!                 else
!                 ionDenVol(iAb,elem,ion) = ionDenVol(iAb,elem,ion) / denominatorIon(iAb,elem,ion)
!                 end if

                 ! Harrington 1982

                 if (denominatorIon(iAb,elem) <= 0.) then
                    ionDenVol(iAb,elem,ion) = 0.
                 else
                    ionDenVol(iAb,elem,ion) = ionDenVol(iAb,elem,ion) / denominatorIon(iAb,elem)
                 end if
              end do
           end do

           ! calculate analytical relative line intensities (relative to Hbeta)
           if (HbetaVol(0) <= 0.) then

              print*, "! outputGas:[warning] Hbeta analytical negative or zero in regionI"

           else

              ! HI rec lines
              do iup = 3, 15
                 do ilow = 2, min0(8,iup-1)
                    HIVol(iAb,iup,ilow) = HIVol(iAb,iup,ilow) /HbetaVol(iAb)
                 end do
              end do

              ! HeI singlets
              HeISVol(iAb,:) = HeISVol(iAb,:) / HbetaVol(iAb)

              ! HeI triplets
              HeITVol(iAb,:) = HeITVol(iAb,:) / HbetaVol(iAb)

              ! HeII rec lines
              do iup = 3, 30
                 do ilow = 2, min0(16, iup-1)
                    HeIIVol(iAb,iup,ilow) = HeIIVol(iAb,iup,ilow) / HbetaVol(iAb)
                 end do
              end do

              ! Heavy elements forbidden lines
              do elem = 3, nElements
                 do ion = 1, min(elem+1, nstages)
                    do iup = 1, nForLevels
                       do ilow = 1, nForLevels
                          forbVol(iAb,elem, ion, iup, ilow) = forbVol(iAb,elem, ion,iup,ilow) / HbetaVol(iAb)
                       end do
                    end do
                 end do
              end do

              if (lgDust .and. convPercent>resLinesTransfer) then
                 do iRes = 1, nResLines
                    resLinesVol(iAb, iRes) = resLinesVol(iAb, iRes)/HbetaVol(iAb)
                    resLinesVolCorr(iAb, iRes) = resLinesVolCorr(iAb, iRes)/HbetaVol(iAb)
                 end do

                 if (lgRecombination) recLinesFlux(iAb,:,:) = recLinesFlux(iAb,:,:)/HbetaVol(iAb)
              end if

           end if


           if (lgDebug) then
              ! calculate relative MC line luminosities
              if (lineLuminosity(iAb,2) <= 0. .and. nIterateMC>1) then
                 print*, "! outputGas: MC luminosty of Hbeta negative or zero",&
                      & lineLuminosity(iAb,2)
              else
                 do l = 1, nLines
                    lineLuminosity(iAb,l) = lineLuminosity(iAb,l)/HbetaLuminosity(iAb)
                 end do
              end if
           end if

        end do

        do iAb = 0, nAbComponents
           ! calculate Hbeta in units of [E36 erg/s]
           ! Note: Hbeta is now in E-25 * E45 ergs/sec (the E-25 comes from the emission
           ! module calculations and the E45 comes from the volume calculations to avoid
           ! overflow. Hence Hbeta is in [E20 ergs/s], so we need to multiply by E-16
           ! to give units of  [E36 erg/s].
           HbetaVol(iAb) = HbetaVol(iAb)*1.e-16         

           ! correct for symmetry case
           if (lgSymmetricXYZ) then
              HbetaVol(iAb)        = 8.*HbetaVol(iAb)
           end if

           ! calculate Hbeta in units of [E36 erg/sec]
           if (lgDebug) HbetaLuminosity(iAb) = HbetaLuminosity(iAb)*Lstar/float(Nphotons)

        end do

        ! write the lineFlux.out file          
        if (present(extMap)) then
           open(unit=10, status='unknown', position='rewind', file='output/lineFlux.ext', iostat=ios)
           if (ios /= 0) then
              print*, "! outputGas: can't open file for writing: lineFlux.out"
              stop
           end if
        else
           open(unit=10, status='unknown', position='rewind', file='output/lineFlux.out', iostat=ios)
           if (ios /= 0) then
              print*, "! outputGas: can't open file for writing: lineFlux.out"
              stop
           end if
        end if


        write(10, *) "Totals integrated over all nebular components: "
        do iAb = 0, nAbComponents

           ! The following code generates a first output with the some common nebular lines
           write(10, *)              
           if (iAb>0) write(10, *) "Component: ", iAb
           write(10, *)
           write(10, *) "Line Ratios (Hbeta=1.) :               Analytical"
           write(10, *) "Hbeta [E36 erg/s]:     ",  HbetaVol(iAb)
           write(10, *)
           write(10, *) "HeI 4471", HeITVol(iAb,6)
           write(10, *) "HeI 4922", HeISVol(iAb,5)
           write(10, *) "HeI 5876", HeITVol(iAb,8)
           write(10, *) "HeI 6678", HeISVol(iAb,8)
           write(10, *) "HeI 7065", HeITVol(iAb,9)
           write(10, *)
           write(10, *) "HeII 4686", HeIIVol(iAb,4,3)
           if (lgElementOn(7) .and. lgDataAvailable(7,2)) then
              write(10, *) 
              write(10, *) "[NII] 5755", forbVol(iAb,7,2,4,5)
              write(10, *) "[NII] 6548", forbVol(iAb,7,2,2,4)
              write(10, *) "[NII] 6584", forbVol(iAb,7,2,3,4)
           end if
           if (lgElementOn(8) .and. lgDataAvailable(8,2)) then              
              write(10, *)
              write(10, *) "[OII] 3726", forbVol(iAb,8,2,1,3)
              write(10, *) "[OII] 3729", forbVol(iAb,8,2,1,2)
              write(10, *) "[OII] 7318,9", forbVol(iAb,8,2,2,4)+forbVol(iAb,8,2,2,5)
              write(10, *) "[OII] 7330,0", forbVol(iAb,8,2,3,4)+forbVol(iAb,8,2,3,5)
           end if
           if (lgElementOn(8) .and. lgDataAvailable(8,3)) then                 
              write(10, *)
              write(10, *) "[OIII] 4363", forbVol(iAb,8,3,4,5)
              write(10, *) "[OIII] 4932", forbVol(iAb,8,3,1,4)
              write(10, *) "[OIII] 4959", forbVol(iAb,8,3,2,4)
              write(10, *) "[OIII] 5008", forbVol(iAb,8,3,3,4)
           end if
           if (lgElementOn(10) .and. lgDataAvailable(10,3)) then              
              write(10, *)
              write(10, *) "[NeIII] 3869", forbVol(iAb,10,3,1,4)
              write(10, *) "[NeIII] 3967", forbVol(iAb,10,3,2,4)
           end if
           if (lgElementOn(16) .and. lgDataAvailable(16,2)) then                 
              write(10, *)
              write(10, *) "[SII] 4069",  forbVol(iAb,16,2,1,5)
              write(10, *) "[SII] 4076",  forbVol(iAb,16,2,1,4)
              write(10, *) "[SII] 6717",  forbVol(iAb,16,2,1,3)
              write(10, *) "[SII] 6731",  forbVol(iAb,16,2,1,2)
           end if
           if (lgElementOn(16) .and. lgDataAvailable(16,3)) then             
              write(10, *) 
              write(10, *) "[SIII] 6312",  forbVol(iAb,16,3,4,5)
           end if
           if (lgElementOn(17) .and. lgDataAvailable(17,3)) then
              write(10, *) 
              write(10, *) "[ClIII] 5518",  forbVol(iAb,17,3,1,3)
              write(10, *) "[ClIII] 5538",  forbVol(iAb,17,3,1,2)
           end if
           if (lgElementOn(17) .and. lgDataAvailable(17,4)) then
              write(10, *)
              write(10, *) "[ClIV] 7531",  forbVol(iAb,17,4,2,4)
              write(10, *) "[ClIV] 8046",  forbVol(iAb,17,4,3,4)
           end if
           if (lgElementOn(18) .and. lgDataAvailable(18,3)) then              
              write(10, *)
              write(10, *) "[ArIII] 7136",  forbVol(iAb,18,3,1,4)
              write(10, *) "[ArIII] 7752",  forbVol(iAb,18,3,2,4)
           end if
           if (lgElementOn(18) .and. lgDataAvailable(18,4)) then
              write(10, *)
              write(10, *) "[ArIV] 4712",  forbVol(iAb,18,4,1,3)
              write(10, *) "[ArIV] 4741",  forbVol(iAb,18,4,1,2)                
           end if

           write(10, *)
           write(10, *) "Line Diagnostics"
           write(10, *) "                  Ne:"
           if (lgElementOn(16) .and. lgDataAvailable(16,2)) &
                & write(10, *) "[SII] 6731/6717 ", forbVol(iAb,16,2,1,2)/ forbVol(iAb,16,2,1,3)
           if (lgElementOn(8) .and. lgDataAvailable(8,2)) &              
                & write(10, *) "[OII] 3729/3726 ", forbVol(iAb,8,2,1,2)/ forbVol(iAb,8,2,1,3)
           if (lgElementOn(17) .and. lgDataAvailable(17,3)) &             
                & write(10, *) "[ClIII] 5537/5517 ", forbVol(iAb,17,3,1,2)/ forbVol(iAb,17,3,1,3)
           if (lgElementOn(18) .and. lgDataAvailable(18,4)) &
                & write(10, *) "[ArIV] 4740/4712 ", forbVol(iAb,18,4,1,2)/ forbVol(iAb,18,4,1,3)
           write(10, *) "                  Te:"
           if (lgElementOn(7) .and. lgDataAvailable(7,2)) & 
                & write(10, *) "[NII](6584+6546)/5754 ", (forbVol(iAb,7,2,2,4)+forbVol(iAb,7,2,3,4))/&
                &forbVol(iAb,7,2,4,5)
           if (lgElementOn(8) .and. lgDataAvailable(8,2)) &
                & write(10, *) "[OII] 3726/7320 ", forbVol(iAb,8,2,1,3)/(forbVol(iAb,8,2,2,4)+&
                &forbVol(iAb,8,2,2,5))
           if (lgElementOn(8) .and. lgDataAvailable(8,3)) &
                & write(10, *) "[OIII] (4959+5007)/4363 ", (forbVol(iAb,8,3,2,4)+forbVol(iAb,8,3,3,4))/&
                &forbVol(iAb,8,3,4,5)
           write(10, *) "HeI 5876/4471 ", HeITVol(iAb,8)/HeITVol(iAb,6)
           write(10, *) "HeI 6678/4471 ", HeISVol(iAb,8)/HeITVol(iAb,6)
           write(10, *)

           write(10, *)
           write(10, *)
           
           if (lgDust .and. convPercent>resLinesTransfer) then
              write(10,*) " Resonance Lines Attenuated by dust absorption"
              write(10,*) " Line                               Uncorrected         Corrected"
              do iRes = 1, nResLines
                 
                 if (lgElementOn(resLine(iRes)%elem)) then
                    write(10,*) trim(resLine(iRes)%species), resLine(iRes)%ion, resLinesVol(iAb,iRes), &
                         &resLinesVolCorr(iAb,iRes)
                 end if
              end do
           end if

           if (lgDebug ) then
              if (HbetaLuminosity(iAb)>0.) then
                 write(10, *) "Line Ratios :               Analytical     MC         & 
                      &                        Analytical/MC:"
                 write(10, *) "Hbeta [E36 erg/s]:     ", &
                      & HbetaVol(iAb), HbetaLuminosity(iAb), HbetaVol(iAb)/HbetaLuminosity(iAb)
              else
                 write(10, *) "Line Ratios :            Formal Solution "
                 write(10, *) "Hbeta [E36 erg/s]:     ", HbetaVol(iAb)
              end if
           else
              write(10, *) "Line Ratios :               Formal Solution "
              write(10, *) "Hbeta [E36 erg/s]:     ", &
                   & HbetaVol(iAb)
           end if

           write(10, *)
           write(10, *) "HI recombination lines:"
           write(10, *)
           iLine = 1
           do iup = 3, 15
              do ilow = 2, min(8,iup-1)

                 if (lgDebug) then
                    if (lineLuminosity(iAb,iLine) > 0. ) then
                       write(10, *) iup, ilow, HIVol(iAb,iup,ilow), lineLuminosity(iAb,iLine), &
                            & HIVol(iAb,iup,ilow)/lineLuminosity(iAb,iLine), iLine
                       sumAn = sumAn + HIVol(iAb,iup,ilow)
                       sumMC = sumMC + lineLuminosity(iAb,iLine)
                    else
                       write(10, *) iup, ilow, HIVol(iAb,iup,ilow), iLine
                    end if
                 else
                    write(10, *) iup, ilow, HIVol(iAb,iup,ilow), iLine
                 end if
                 iLine = iLine + 1
              end do
           end do

           write(10, *)
           write(10, *) "HeI singlets"
           write(10, *)
           do l = 1, 9

              if (lgDebug) then
                 if (lineLuminosity(iAb,iLine) > 0. ) then
                    write(10, *) l,"            ", lamS(l), HeISVol(iAb,l), lineLuminosity(iAb,iLine), &
                         & HeISVol(iAb,l)/lineLuminosity(iAb,iLine), iLine
                    sumAn = sumAn + HeISVol(iAb,l)
                    sumMC = sumMC + lineLuminosity(iAb,iLine) 
                 else
                    write(10, *) l,"            ", lamS(l), HeISVol(iAb,l), iLine
                 end if
              else
                 write(10, *) l,"            ", lamS(l), HeISVol(iAb,l), iLine
              end if
              iLine = iLine + 1
           end do

           write(10, *)
           write(10, *) "HeI triplets:"
           do l = 1, 11

              if (lgDebug) then
                 if ( lineLuminosity(iAb,iLine) > 0. ) then
                    write(10, *) l,"            ", lamT(l), HeITVol(iAb,l), lineLuminosity(iAb,iLine),&
                         & HeITVol(iAb,l)/lineLuminosity(iAb,iLine), iLine
                    sumAn = sumAn + HeITVol(iAb,l)
                    sumMC = sumMC + lineLuminosity(iAb,iLine)
                 else
                    write(10, *) l,"            ", lamT(l), HeITVol(iAb,l), iLine
                 end if
              else
                 write(10, *) l,"            ", lamT(l), HeITVol(iAb,l), iLine
              end if
              iLine = iLine + 1
           end do
              
           write(10, *)
           write(10, *) "HeII recombination lines:"
           write(10, *)
           do iup = 3, 30
              do ilow = 2, min(16, iup-1)

                 if (lgDebug ) then
                    if ( lineLuminosity(iAb,iLine) > 0. ) then
                       write(10, *) iup, ilow, HeIIVol(iAb,iup,ilow), lineLuminosity(iAb,iLine), &
                            & HeIIVol(iAb,iup,ilow)/lineLuminosity(iAb,iLine), iLine
                       sumAn = sumAn + HeIIVol(iAb,iup,ilow)
                       sumMC = sumMC + lineLuminosity(iAb,iLine)
                    else
                       write(10, *) iup, ilow, HeIIVol(iAb,iup,ilow), iLine
                    end if
                 else
                    write(10, *) iup, ilow, HeIIVol(iAb,iup,ilow), iLine
                 end if
                 
                 iLine = iLine + 1
              end do
           end do
              
           write(10, *)
           write(10, *) "Heavy ions forbidden lines"
           write(10, *)
           do elem = 3, nElements
              do ion = 1, min(elem+1, nstages)
                 if (.not.lgElementOn(elem)) exit
                 if (lgDataAvailable(elem,ion)) then
                    do iup = 1, nForLevels
                       do ilow = 1, nForLevels
                          
                          if (forbVol(iAb,elem,ion, iup, ilow) > 0.) then
                             if (lgDebug) then
                                if (lineLuminosity(iAb,iLine) > 0. ) then
                                   write(10, *) elem, ion, iup, ilow, wav(elem,ion, iup, ilow), &
                                        & forbVol(iAb,elem,ion, iup, ilow), lineLuminosity(iAb,iLine), &
                                        & forbVol(iAb,elem, ion, iup, ilow)/lineLuminosity(iAb,iLine), iLine
                                   sumAn = sumAn + forbVol(iAb,elem,ion,iup,ilow)
                                   sumMC = sumMC + lineLuminosity(iAb,iLine)
                                else
                                   write(10, *) elem, ion, iup, ilow, wav(elem,ion, iup, ilow), &
                                        & forbVol(iAb,elem,ion,iup,ilow), iLine
                                end if
                             else
                                write(10, *) elem, ion, iup, ilow, wav(elem,ion, iup, ilow), & 
                                     & forbVol(iAb,elem,ion,iup,ilow), iLine
                             end if
                          end if
                          
                          iLine = iLine + 1
                          
                       end do
                    end do
                 end if
              end do
           end do
              
           if (lgRecombination) then
              write(10,*)
              write(10,*)
              write(10,*) "Recombination Lines for CII, Davey et al. (2000)"
              write(10,*) 
              do i = 1, 159
                 write(10,*) recLambdaCII(i), recLinesFlux(iAb,4,i)
              end do
                 
              write(10,*)
              write(10,*)
              write(10,*) "Recombination Lines for NII, Kisielius & Storey(2000)"
              write(10,*)
              do i = 1,115
                 write(10,*) recLambdaN33II(i), recLinesFlux(iAb,5,i)
              end do
              write(10,*) "3d--4f Escalante & Victor(1990)"
              write(10,*)
              do i = 1,23
                 write(10,*) recLambdaN34II(i), recLinesFlux(iAb,6, i)
              end do
             
              write(10,*)
              write(10,*)
              write(10,*) "Recombination Lines for OII, Storey & Hummer(1994) and Liu et al. (1995)"
              write(10,*)
              do i = 1, 415
                 write(10,*) recLambdaOII(i), recLinesFlux(iAb,1,i)
              end do
              
              write(10,*)
              write(10,*)
              write(10,*) "Recombination Lines for NeII, Kisielius et al. (1998)&
                   & and Storey (private commumication)"
              write(10,*)
              do i = 1,439
                 write(10,*) recLambdaNeII(i), recLinesFlux(iAb,3,i)
              end do
              
              write(10,*)
              write(10,*)
              write(10,*) "Recombination Lines for MgII 4481, similar to CII 4667"
              write(10,*)
              write(10,*) "4481.21 ", recLinesFlux(iAb,2,1)+recLinesFlux(iAb,2,2)&
                   &+recLinesFlux(iAb,2,3)
                 
           end if

           LtotAn = HbetaVol(iAb)*sumAn
           if(lgDebug) LtotMC = HbetaLuminosity(iAb)*sumMC
           
        end do
        
        ! close lineFlux.out file
        close(10)
        
        ! write the temperature.out file
        open(unit=20, status='unknown', position='rewind', file='output/temperature.out', iostat=ios)
        if (ios /= 0) then
           print*, "! outputGas: can't open file for writing: temperature.out"
           stop
        end if
        
        
        ! write ionratio.out file
        open(unit=30, status='unknown', position='rewind', file='output/ionratio.out', iostat=ios)
        if (ios /= 0) then
           print*, "! outputGas: can't open file for writing: ionratio.out"
           stop
        end if
        
        if (lgDebug) then
           
           open(unit=60, status='unknown', position='rewind', file='output/ionDen.out', iostat=ios)
           if (ios /= 0) then
              print*, "! outputGas: can't open file for writing: ionDen.out"
              stop
           end if

        end if
        
        
        write(20, *)
        write(20, *) "Mean ionic temperatures Te(ion)"
        write(20, *)
        write(20, *) "Total, integrated over all nebular components"
        
        write(30, *)
        write(30, *) "Mean ionic ratio <ion>/<H+>"
        write(30, *)
        write(30, *) "Total, integrated over all nebular components"
        write(30, *) 
        
        do iAb = 0, nAbComponents
           
           if (iAb>0) then
              
              write(20, *)
              write(20, *) "Mean ionic temperatures Te(ion)"
              write(20, *)
              write(20, *) "Component : ", iAb
              write(20, *) 
              
              write(30, *)
              write(30, *) "Mean ionic ratio <ion>/<H+>"
              write(30, *)
              write(30, *) "Component : ", iAb
              write(30, *) 
              
           end if

           write(20, *) "Element      Ion        Te(Element,ion)"
           write(20, *)
           do elem = 1, nElements
              do ion = 1, nstages
                 write(20, *) elem, ion,  TeVol(iAb,elem, ion)
              end do
           end do
           
           write(30, *) "Element      Ion        <ion>/<H+>I     <ion>/<H+>II"
           write(30, *)
           do elem = 1, nElements
              do ion = 1, nstages
                 write(30, *) elem, ion, ionDenVol(iAb,elem, ion)
              end do
           end do
           
           if (lgDebug) then
              
              write(60, *)
              do iG = 1, nGrids
                 print*, 'Grid : ', iG
                 do i = 1 , grid(iG)%nx
                    do j = 1, grid(iG)%ny
                       do k = 1, grid(iG)%nz
                          do elem = 1, nElements
                             do ion = 1, nstages
                                if (grid(iG)%active(i,j,k)<=0) exit
                                if (.not.lgElementOn(elem)) exit
                                write(60, *) i,j,k, elem, ion, grid(iG)%ionDen(grid(iG)%active(i,j,k),elementXref(elem), ion)
                             end do
                          end do
                       end do
                    end do
                 end do
              end do

              close(60)
           end if
           
        end do

        close(20)
        close(30)
        close(60)
             
        ! find the run of the optical depths from the illuminated
        ! surface to the edge of the nebula 
        
        ! polar direction
        
        ! define initial position
        aVec%x = 0.
        aVec%y = 0.
        aVec%z = 0.
          
        ! define direction
        uHat%x = 0.
        uHat%y = 0.
        uHat%z = 1.
        
        ! allocate space for temporary optical depth arrays
        allocate (absTau(1:maxTau), stat = err)
        if (err /= 0) then
           print*, "! adjustGrid: can't allocate array memory"
           stop
        end if
        allocate (lambda(1:maxTau), stat = err)
        if (err /= 0) then
           print*, "! adjustGrid: can't allocate array memory"
           stop
        end if
        
        open(unit=70, file='output/tau.out', status='unknown', position='rewind', iostat = ios)
             
        
        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
        nTau   = 0

        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 1., nTau, absTau, lambda)
          
        
        write(70, *) " Optical depth from the centre to the edge of the nubula "
        
        write(70,*) " Polar direction "

        write(70,*) " tau(H) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
             
        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
        
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 1.8, nTau, absTau, lambda)
        
        write(70,*) " tau(He) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
        
        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
        
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 4., nTau, absTau, lambda)
        
        write(70,*) " tau(He+) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
        
        ! equatorial direction (along y axis)
        
        ! define initial position
        aVec%x = 0.
        aVec%y = 0.
        aVec%z = 0.
        
        ! define direction
        uHat%x = 0.
        uHat%y = 1.
        uHat%z = 0.


        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
          
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 1., nTau, absTau, lambda)
        
        write(70,*) " Equatorial Direction (along y-axis) "
        
        write(70,*) " tau(H) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
        
        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
        
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 1.8, nTau, absTau, lambda)
          
        write(70,*) " tau(He) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
          
        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
        
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 4., nTau, absTau, lambda)
          
        write(70,*) " tau(He+) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
          
        ! equatorial (x-axis)
        
        ! define initial position
        aVec%x = 0.
        aVec%y = 0.
        aVec%z = 0.
        
        ! define direction
        uHat%x = 1.
        uHat%y = 0.
        uHat%z = 0.
          

        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
          
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 1., nTau, absTau, lambda)
          
        write(70,*) " Equatorial Direction (along x-axis) "
        
        write(70,*) " tau(H) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
          
        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
        
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 1.8, nTau, absTau, lambda)
        
        write(70,*) " tau(He) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
        
        ! initialize arrays with zero
        absTau = 0.
        lambda = 0.
        
        ! find the optical depth
        call integratePathTau(grid, aVec, uHat, 4., nTau, absTau, lambda)
          
        write(70,*) " tau(He+) "
        do i = 1, nTau
           write(70, *) lambda(i), absTau(i)
        end do
        
        close (70)
        
        ! free the space allocated to the temp arrays
        if (associated(absTau)) deallocate(absTau)
        if (associated(lambda)) deallocate(lambda)
        if (associated(HIVol)) deallocate(HIVol)
        if (associated(HeISVol)) deallocate(HeISVol)
        if (associated(HeITVol)) deallocate(HeITVol)
        if (associated(HeIIVol)) deallocate(HeIIVol)
        if (associated(ionDenVol)) deallocate(ionDenVol)
        if (lgDebug) then
           if (associated(lineLuminosity)) deallocate(lineLuminosity)
        end if
        if (associated(forbVol)) deallocate(forbVol)
        if (associated(TeVol)) deallocate(TeVol)
        if (associated(recLinesFlux)) deallocate(recLinesFlux)
        if (associated(denominatorIon)) deallocate(denominatorIon)
        if (associated(denominatorTe)) deallocate(denominatorTe)
        
        if (present(extMap)) then 
           if (associated(cMap)) deallocate(cMap)
           if (associated(flam)) deallocate(flam)
        end if
        if (convPercent >= resLinesTransfer .and. lgDust) then
           if (associated(resLinesVol)) deallocate(resLinesVol)
           if (associated(resLinesVolCorr)) deallocate(resLinesVolCorr)
        end if

      contains
      
! optical recombination lines subroutines added by Zhang Yong (PKU) February 2003
!***************** for recombination****************************************************

        subroutine roii(lamb,flux,tk,den)
!        ref Storey 1994 A&A 282, 999, Liu 1995, MNRAS, 272, 369
          implicit none

          real, intent(in) :: tk,den
          real(kind=8), intent(inout):: lamb(500),flux(500)

          real(kind=8)  :: ahb,te,emhb,an(4), &
               &        a,b,c,d,logne,aeff,br(3,500),em
          integer       :: i,g2(500)

          open(file="data/Roii.dat",unit=41,status="old", position="rewind")
          do i=1,415
             read(41,*) lamb(i),g2(i),&
                  &br(1,i),br(2,i),br(3,i)
          end do
!          110 format (6x,f9.4,31x,A4,27x,A7,17x,i2,5x,a7,2x,f6.4,2x,f6.4,2x,f6.4)
          logne=log10(den)
!   4f-3d transitions (Case A=B=C for a,b,c,d as well as Br)
          a=0.232
          b=-0.92009
          c=0.15526
         d=0.03442
         an(1)=0.236
         an(2)=0.232
         an(3)=0.228
         an(4)=0.222
         te=tk/10000.
         ahb=6.68e-14*te**(-0.507)/(1.+1.221*te** 0.653)
         emhb=1.98648E-08/4861.33*ahb
         if(logne.le.2) then
           a=an(1)
          elseif(logne.le.4) then
           a=an(1)+(an(2)-an(1))/2.*(logne-2.)
          elseif(logne.le.5) then
           a=an(2)+(an(3)-an(2))*(logne-2.)
          elseif(logne.le.6) then
           a=an(3)+(an(4)-an(3))*(logne-2.)
          else
           a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te) ** 2)
         do i=1,183
          em=aeff*1.98648E-08/lamb(i)*g2(i)*br(2,i)
          flux(i)=em/emhb
         end do
!       3d-3p ^4F transitions (Case A=B=C for a,b,c,d; Br diff.
!        slightly, adopt Case B)
         a=0.876
         b=-0.73465
         c=0.13689
         d=.06220
         an(1)=0.876
         an(2)=0.876
         an(3)=0.877
         an(4)=0.880
         if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
             a=an(4)
          endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=184,219
          em=aeff*1.98648E-08/lamb(i)*g2(i)*br(2,i)
          flux(i)=em/emhb
         end do
!        3d-3p ^4D, ^4P transitions
         a=0.745
         b=-0.74621
         c=0.15710
         d=0.07059
         an(1)=0.747
         an(2)=0.745
         an(3)=0.744
         an(4)=0.745
         if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff = 1.e-14*a*te**(b)
         aeff =aeff*(1. +c *(1. - te) +d * (1.-te) ** 2)
         do i=220,310
          em=aeff*1.98648E-08/lamb(i)*g2(i)*br(2,i)
          flux(i)=em/emhb
         end do
!     3d-3p ^2F transitions
         a=0.745
         b=-0.74621
         c=0.15710
         d=0.07059
         an(1)=0.727
         an(2)=0.726
         an(3)=0.725
         an(4)=0.726
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=311,328
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(1,i)
            flux(i)=em/emhb
         end do
!       3d-3p ^2D transitions
         a=0.601
         b=-0.79533
         c=0.15314
         d=0.05322
         an(1)=0.603
         an(2)=0.601
         an(3)=0.600
         an(4)=0.599
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=329,358
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(1,i)
            flux(i)=em/emhb
         end do
!     3d-3p ^2P transitions
         a=0.524
         b=-0.78448
         c=0.13681
         d=0.05608
         an(1)=0.526
         an(2)=0.524
         an(3)=0.523
         an(4)=0.524
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=359,388
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(1,i)
            flux(i)=em/emhb
         end do
!      3p-3s ^4D - ^4P transitions
         a=36.2
         b=-0.736
         c=0.033
         d=0.077
         an(1)=36.
         an(2)=36.2
         an(3)=36.4
         an(4)=36.3
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=389,396
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(2,i)
            flux(i)=em/emhb
         end do
!     3p-3s ^4P - ^4P transitions
         a=14.6
         b=-0.732
         c=0.081
         d=0.066
         an(1)=14.6
         an(2)=14.6
         an(3)=14.7
         an(4)=14.6
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=397,403
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(2,i)
            flux(i)=em/emhb
         end do
!       3p-3s ^4S - ^4P transitions
         a=4.90
         b=-0.730
         c=-0.003
         d=0.057
         an(1)=4.80
         an(2)=4.90
         an(3)=4.90
         an(4)=4.90
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=404,406
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(2,i)
            flux(i)=em/emhb
         end do
!       3p-3s ^2D - ^2P transitions
         a=2.40
         b=-0.550
         c=-0.051
         d=0.178
         an(1)=2.40
         an(2)=2.40
         an(3)=2.50
         an(4)=2.60
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=407,409
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(1,i)
            flux(i)=em/emhb
         end do
!       3p-3s ^2P - ^2P transitions
         a=1.20
         b=-0.523
         c=-0.044
         d=0.173
         an(1)=1.10
         an(2)=1.20
         an(3)=1.20
         an(4)=1.20
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=410,413
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(1,i)
            flux(i)=em/emhb
         end do
!     3p-3s ^2S - ^2P transitions
         a= 0.40
         b=-0.461
         c=-0.083
         d=0.287
         an(1)=0.40
         an(2)=0.40
         an(3)=0.40
         an(4)=0.40
        if(logne.le.2) then
            a=an(1)
           elseif(logne.le.4) then
            a=an(1)+(an(2)-an(1))/ 2.*(logne-2.)
           elseif(logne.le.5) then
            a=an(2)+(an(3)-an(2))*(logne-2.)
           elseif(logne.le.6) then
            a=an(3)+(an(4)-an(3))*(logne-2.)
           else
            a=an(4)
         endif
         aeff=1.e-14*a*te**(b)
         aeff=aeff*(1.+c*(1.-te)+d*(1.-te)**2)
         do i=414,415
            em=aeff*1.98648E-08/lamb(i)*g2(i)*br(1,i)
            flux(i)=em/emhb
         end do
         close(unit=41)
         return
       end subroutine roii


         subroutine rmgii(fluxremg, lambd, tk)
         implicit none
         real, intent(in) :: tk
         real(kind=8),intent(inout) :: fluxremg(500), lambd(500)
         real(kind=8) ::te,ahb,emhb,&
         &         aeff,a,b,c,d,f
         data a,b,c,d,f/27.586,-0.055,-0.039,-0.208,-1.1416/
          te=tk/10000.d0
          ahb=6.68e-14*te**(-0.507)/(1.+1.221*te** 0.653)
          emhb=1.98648E-08/4861.33*ahb
          aeff=1.e-14*a*te**(f)
          aeff=aeff*(1.+b*(1.-te)+c*(1-te)**2+d*(1-te)**3)
          lambd(1)=4481.13
          lambd(2)=4481.15
          lambd(3)=4481.32
          fluxremg(1)=aeff*1.98648E-08/4481.13/emhb*4/7
          fluxremg(2)=aeff*1.98648E-08/4481.15/emhb*28/70
          fluxremg(3)=aeff*1.98648E-08/4481.32/emhb*2/70
         return
         end subroutine rmgii

       subroutine rneii(lamb,flux,tk)
!      ref Kisielius AAS, 133, 257
       implicit none
         real, intent(in) :: tk
         real(kind=8),intent(inout) :: flux(500), lamb(500)
         real(kind=8)  :: te,a,b,c,d,f,ahb,emhb,aeff,br
         integer :: i
         te=tk/10000.d0
         ahb=6.68e-14*te**(-0.507)/(1.+1.221*te** 0.653)
         emhb=1.98648E-08/4861.33*ahb
         open(unit=50,file='data/Rneii.dat',status='old', position='rewind')
         do i=1,426
          read(50,*) a,b,c,d,f,lamb(i),br
          aeff=1.e-14*a*te**(f)
          aeff=aeff*(1.+b*(1.-te)+c*(1-te)**2+d*(1-te)**3)
          flux(i)=aeff*1.98648E-08/lamb(i)/emhb*br
         end do
!         lamb(427)=4391.986
!         flux(427)=0.0966d-1
!         lamb(428)=4409.299
!           flux(428)=0.0642d-1
!         lamb(429)=4379.552
!          flux(429)=0.0598d-1
!         lamb(430)=4428.611
!           flux(430)=0.0422d-1
!         lamb(431)=4219.745
!          flux(431)=0.0536d-1
!                   lamb(432)=4397.988
!          flux(432)=0.0334d-1
!         lamb(433)=4430.944
!          flux(433)=0.0273d-1
!         lamb(434)=4413.217
!          flux(434)=0.0231d-1
!         lamb(435)=4233.853
!          flux(435)=0.0134d-1
!         lamb(436)=4457.051
!          flux(436)=0.00952d-1
!         lamb(437)=4231.635
!          flux(437)=0.0127d-1
!         lamb(438)=4421.391
!          flux(438)=0.00864d-1
!         lamb(439)=4250.639
!          flux(439)=0.00849d-1
         close(unit=50)
!         return
         end subroutine rneii

         subroutine rcii(lamb,flux,tk)
!        ref Davey A&As 2000 142, 85
         implicit none
         real, intent(in) ::tk
         real(kind=8), intent(inout) :: lamb(500),flux(500)
         real(kind=8)          ::te,a,b,c,d,f,ahb,emhb,aeff,br
         integer :: i
         te=tk/10000.d0
         ahb=6.68e-14*te**(-0.507)/(1.+1.221*te** 0.653)
         emhb=1.98648E-08/4861.33*ahb
         open(unit=51,file='data/Rcii.dat',status='old', position='rewind')
         do i=1,159
          read(51,*) a,b,c,d,f,lamb(i),br
          aeff=1.e-14*a*te**(f)
          aeff=aeff*(1.+b*(1.-te)+c*(1-te)**2+d*(1-te)**3)
          flux(i)=aeff*1.98648E-08/lamb(i)/emhb*br
         end do
         close(unit=51)
!         return
         end subroutine rcii

         subroutine rnii(lamb,flux,tk,den)
!        ref Storey 2002, A&A, 387, 1135
         implicit none
         real, intent(in):: tk,den
         real(kind=8),  intent(inout) :: lamb(500),flux(500)
         real(kind=8) ::logden,te,a,b,c,d,&
          &    f,u,v,ahb,emhb,aeff,br,y
         integer :: i
          te=tk/10000.d0
          logden=log10(den)
          y=logden-4.
          ahb=6.68e-14*te**(-0.507)/(1.+1.221*te** 0.653)
          emhb=1.98648E-08/4861.33*ahb
          open(unit=52,file='data/Rnii.dat',status='old', position='rewind')
          do i=1,115
           read(52,*) a,b,c,d,f,u,v,lamb(i),br
           aeff=1.e-14*a*te**(f)
           aeff=aeff*(1+0.01*u*y+0.001*v*y**2)
           aeff=aeff*(1.+b*(1.-te)+c*(1-te)**2+d*(1-te)**3)
           flux(i)=aeff*1.98648E-08/lamb(i)/emhb*br
          end do
           close(unit=52)
!          return
          end subroutine rnii

          subroutine rnii4f(lamb,flux,tk)
!     compute N II 3d--4f, ref Escalante 1990, ApJs, 73, 513
          implicit none
          real, intent(in) :: tk
          real(kind=8), intent(inout) :: lamb(500),flux(500)
          real(kind=8)  :: te,den,ahb,emhb,aeff,&
           &  a(51),b(51),c(51),br(500),em,a1,b1,c1,d1,z,br1
          integer :: i
          do i=1,500
           lamb(i)=0.d0
           flux(i)=0.d0
          end do
          te=tk/10000.d0
          ahb=6.68e-14*te**(-0.507)/(1.+1.221*te**0.653)
          emhb=1.98648E-08/4861.33*ahb
          open(unit=61,file="data/Rniiold.dat",status='old', position='rewind')
          open(unit=62,file="data/Rnii_aeff.dat",status='old', position='rewind')
          do i=1,51
           read(62,*) a(i),b(i),c(i)
          end do
          do i=1,99
           read(61,*) lamb(i),br(i)
          end do
          aeff=10.**(a(41)+b(41)*log10(te)+c(41)*log10(te)**2)
          do i=77,82
           em=aeff*1.98648E-08/lamb(i)*br(i)
           flux(i)=em/emhb
          end do
          aeff=10.**(a(42)+b(42)*log10(te)+c(42)*log10(te)**2)
           em=aeff*1.98648E-08/lamb(83)*br(83)
           flux(83)=em/emhb
          aeff=10.**(a(45)+b(45)*log10(te)+c(45)*log10(te)**2)
          do i=84,89
           em=aeff*1.98648E-08/lamb(i)*br(i)
           flux(i)=em/emhb
          end do
        aeff=10.**(a(47)+b(47)*log10(te)+c(47)*log10(te)**2)
          do i=90,95
           em=aeff*1.98648E-08/lamb(i)*br(i)
           flux(i)=em/emhb
          end do
        aeff=10.**(a(48)+b(48)*log10(te)+c(48)*log10(te)**2)
           em=aeff*1.98648E-08/lamb(96)*br(96)
           flux(96)=em/emhb
        aeff=10.**(a(49)+b(49)*log10(te)+c(49)*log10(te)**2)
           em=aeff*1.98648E-08/lamb(97)*br(97)
           flux(97)=em/emhb
          a1=0.108
          b1=-0.754
          c1=2.587
          d1=0.719
          z=2.
          br1=0.35
          aeff=1.e-13*z*a1*(te/z**2)**(b1)
          aeff=aeff/(1.+c1*(te/z**2)**(d1))*br1
          em=aeff*1.98648E-08/lamb(98)*br(98)
          flux(98)=em/emhb
          a1=0.326
          b1=-0.754
          c1=2.587
          d1=0.719
          z=2.
          Br1=0.074
          aeff=1.e-13*z*a1*(te/z**2)**(b1)
          aeff=aeff/(1.+c1*(te/z**2)**(d1))*br1
          em=aeff*1.98648E-08/lamb(99)*br(99)
          flux(99)=em/emhb
          do i=1,23
           lamb(i)=lamb(i+76)
           flux(i)=flux(i+76)
          end do
          do i=1,99
          end do
          close(unit=61)
          close(unit=62)
!          return
          end  subroutine rnii4f



    ! this subroutine is the driver for the calculation of the emissivity
    ! from the heavy elements forbidden lines. 
    subroutine forLines()
        implicit none

        integer                     :: elem, ion ! counters

        ! re-initialize forbiddenLines
        forbiddenLines = 0.

        do elem = 3, nElements
           do ion = 1, min(elem+1, nstages)
              if (.not.lgElementOn(elem)) exit

              if (lgDataAvailable(elem, ion)) then

                 if (ion<nstages) then
                    call equilibrium(dataFile(elem, ion), ionDenUsed(elementXref(elem),ion+1), &
                         & TeUsed, NeUsed, forbiddenLines(elem, ion,:,:), wav(elem,ion,:,:))
                 else
                    call equilibrium(dataFile(elem, ion), 0., &
                         & TeUsed, NeUsed, forbiddenLines(elem, ion,:,:), wav(elem,ion,:,:))
                 end if


                 forbiddenLines(elem, ion, :, :) =forbiddenLines(elem, ion, :, :)*elemAbundanceUsed(elem)*&
                      & ionDenUsed(elementXref(elem), ion)

              end if

           end do
        end do


        ! scale the forbidden lines emissivity to give units of [10^-25 erg/s/Ngas]
        ! comment: the forbidden line emissivity is so far in units of cm^-1/s/Ngas
        !          the energy [erg] of unit wave number [cm^-1] is 1.9865e-16, hence 
        !          the right units are obtained by multiplying by 1.9865e-16*1e25 
        !          which is 1.9865*1e9 
        forbiddenLines = forbiddenLines*1.9865e9

    end subroutine forLines    

    subroutine RecLinesEmission()
        implicit none

        ! local variables
        integer                    :: ios         ! I/O error status
        integer                    :: i           ! counters
        integer                    :: ilow,&      ! pointer to lower level
&                                      iup        ! pointer to upper level

        real                       :: A4471, A4922! HeI reference lines 
        real                       :: aFit        ! general interpolation coeff
        real                       :: C5876, C6678! collition exc. corrections
        real                       :: Hbeta       ! Hbeta emission
        real                       :: HeII4686    ! HeII 4686 emission
        real                       :: Lalpha      ! Lalpha emission
        real                       :: T4          ! TeUsed/10000.

        real, dimension(9,3)       :: HeISingRead ! array reader for HeI sing rec lines
        real, dimension(11,3)       :: HeITripRead ! array reader for HeI trip  rec lines  

        ! do hydrogenic ions first

        ! read in HI recombination lines [e-25 ergs*cm^3/s] 
        ! (Storey and Hummer MNRAS 272(1995)41)
        close(94)
        open(unit = 94, file = "data/r1b0100.dat", status = "old", position = "rewind", iostat=ios)
        if (ios /= 0) then
            print*, "! RecLinesEmission: can't open file: data/r1b0100.dat"
            stop
        end if
        do iup = 15, 3, -1
            read(94, fmt=*) (HIRecLines(iup, ilow), ilow = 2, min0(8, iup-1)) 
        end do

        close(94)

        ! calculate Hbeta 
        Hbeta = 2530./(TeUsed**0.833) ! TeUsed < 26000K CASE 
        ! fits to Storey and Hummer MNRAS 272(1995)41
!        Hbeta = 10**(-0.870*log10Te + 3.57)
        Hbeta = Hbeta*NeUsed*ionDenUsed(elementXref(1),2)*elemAbundanceUsed(1)

        ! calculate emission due to HI recombination lines [e-25 ergs/s/cm^3]
        do iup = 15, 3, -1
            do ilow = 2, min0(8, iup-1)
                HIRecLines(iup, ilow) = HIRecLines(iup, ilow)*Hbeta
            end do
        end do    

        ! add contribution of Lyman alpha 
        ! fits to Storey and Hummer MNRAS 272(1995)41
        Lalpha = 10**(-0.897*log10Te + 5.05) 
        HIRecLines(15, 8) =HIRecLines(15, 8) + elemAbundanceUsed(1)*ionDenUsed(elementXref(1),2)*&
             & NeUsed*Lalpha 
        

        ! read in HeII recombination lines [e-25 ergs*cm^3/s]
        ! (Storey and Hummer MNRAS 272(1995)41)
        close(95)
        open(unit = 95, file = "data/r2b0100.dat", status = "old", position = "rewind", iostat=ios)
        if (ios /= 0) then
            print*, "! RecLinesEmission: can't open file: data/r2b0100.dat"
            stop
        end if
        do iup = 30, 3, -1
            read(95, fmt=*) (HeIIRecLines(iup, ilow), ilow = 2, min0(16, iup-1))
        end do

        close(95)


        ! calculate HeII 4686 [E-25 ergs*cm^3/s]
        HeII4686 = 10.**(-.997*log10(TeUsed)+5.16)
        HeII4686 = HeII4686*NeUsed*elemAbundanceUsed(2)*ionDenUsed(elementXref(2),3)

        ! calculate emission due to HeI recombination lines [e-25 ergs/s/cm^3]
        do iup = 30, 3, -1
            do ilow = 2, min0(16, iup-1)
                HeIIRecLines(iup, ilow) = HeIIRecLines(iup, ilow)*HeII4686
            end do
        end do    


        ! now do HeI
        
        ! read in HeI singlet recombination lines [e-25 ergs*cm^3/s]
        ! Benjamin, Skillman and Smits ApJ514(1999)307
        close(96)
        open(unit = 96, file = "data/heIrecS.dat", status = "old", position = "rewind", iostat=ios)
        if (ios /= 0) then
            print*, "! RecLinesEmission: can't open file: data/heIrecS.dat"
            stop
        end if
        do i = 1, 9
            read(96, fmt=*) HeISingRead(i, :), lamS(i)

            ! interpolate over temperature (log10-log10 space)
            if (TeUsed <= 5000.) then
                HeIRecLinesS(i) = HeISingRead(i, 1)
            else if (TeUsed >= 20000.) then
                HeIRecLinesS(i) = HeISingRead(i, 3)
            else if ((TeUsed > 5000.) .and. (TeUsed <= 10000.)) then
                aFit = log10(HeISingRead(i, 2)/HeISingRead(i, 1)) / log10(2.)
                HeIRecLinesS(i) = 10**(log10(HeISingRead(i, 1)) + &
&                                  aFit*log10(TeUsed/5000.) ) 
            else if ((TeUsed > 10000.) .and. (TeUsed < 20000.)) then
                aFit = log10(HeISingRead(i, 3)/HeISingRead(i, 2)) / log10(2.)
                HeIRecLinesS(i) = 10**(log10(HeISingRead(i, 2)) + &
&                                  aFit*log10(TeUsed/10000.) )
            end if
        end do

        close(96)
        
        ! read in HeI triplet recombination lines [e-25 ergs*cm^3/s]
        ! Benjamin, Skillman and Smits ApJ514(1999)307
        close(97)
        open(unit = 97, file = "data/heIrecT.dat", status = "old", position = "rewind", iostat=ios)
        if (ios /= 0) then
            print*, "! RecLinesEmission: can't open file: data/heIrecT.dat"
            stop
        end if
        do i = 1, 11
            read(97, fmt=*) HeITripRead(i, :), lamT(i)

            ! interpolate over temperature (log10-log10 space)
            if (TeUsed <= 5000.) then
                HeIRecLinesT(i) = HeITripRead(i, 1)
            else if (TeUsed >= 20000) then
                HeIRecLinesT(i) = HeITripRead(i, 3)
            else if ((TeUsed > 5000.) .and. (TeUsed <= 10000.)) then
                aFit = log10(HeITripRead(i, 2)/HeITripRead(i, 1)) / log10(2.)
                HeIRecLinesT(i) = 10**(log10(HeITripRead(i, 1)) + &
&                                  aFit*log10(TeUsed/5000.) )
            else if ((TeUsed > 10000.) .and. (TeUsed < 20000.)) then
                aFit = log10(HeITripRead(i, 3)/HeITripRead(i, 2)) / log10(2.)
                HeIRecLinesT(i) = 10**(log10(HeITripRead(i, 2)) + &
&                                  aFit*log10(TeUsed/10000.) )
            end if
        end do

        close(97)

        HeIRecLinesS = HeIRecLinesS*NeUsed*elemAbundanceUsed(2)*ionDenUsed(elementXref(2),2)
        HeIRecLinesT = HeIRecLinesT*NeUsed*elemAbundanceUsed(2)*ionDenUsed(elementXref(2),2)

                                                   
    end subroutine RecLinesEmission

    end subroutine outputGas

    subroutine writeTau(grid)
      implicit none

      type(grid_type), intent(in) :: grid(*)

      type(vector) :: aVec, uHat        
      
      real, pointer :: outTau(:), lambda(:)
      real          :: nuR

      integer :: nTau, err, i, ios

      ! find the run of the optical depths from the illuminated
      ! surface to the edge of the nebula
            
      ! allocate space for temporary optical depth arrays
      allocate (outTau(1:maxTau), stat = err)
      if (err /= 0) then
         print*, "! adjustGrid: can't allocate array memory"
         stop
      end if
      allocate (lambda(1:maxTau), stat = err)
      if (err /= 0) then
         print*, "! adjustGrid: can't allocate array memory"
         stop
      end if
      
      close(73)
      open(unit=73, file='output/tau.out', status='unknown', position='rewind', iostat = ios)

      aVec%x = 0.
      aVec%y = 0.
      aVec%z = 0.      

      uHat%x = 1.
      uHat%y = 0.
      uHat%z = 0.

      ! initialize arrays with zero
      outTau = 0.
      lambda = 0.
      nTau   = 0

      ! 0.55um = 0.165690899
      ! 1.00um = 0.0912 
      nuR = 0.0912
      

      ! find the optical depth
      call integratePathTau(grid, aVec, uHat, nuR, nTau, outTau, lambda)
 
     
      write(73, *) " Optical depth from the centre to the edge of the nubula "
      write(73, *) " direction: 1,0,0 - nu = 0.0912 Ryd -> lambda = 1.0 um"
      
      do i = 1, nTau
         write(73, *) lambda(i), outTau(i)
      end do

      write(73,*) ' '

      aVec%x = 0.
      aVec%y = 0.
      aVec%z = 0.

      uHat%x = 1./sqrt(3.)
      uHat%y = 1./sqrt(3.)
      uHat%z = 1./sqrt(3.)

      ! initialize arrays with zero
      outTau = 0.
      lambda = 0.
      nTau   = 0

      ! find the optical depth
      call integratePathTau(grid, aVec, uHat, nuR, nTau, outTau, lambda)
 
     
      write(73, *) " Optical depth from the centre to the edge of the nubula "
      write(73, *) " direction: 1,1,1 - nu = 0.0911 Ryd -> lambda = 1.0 um"
      
      do i = 1, nTau
         write(73, *) lambda(i), outTau(i)
      end do

      write(73,*) ' '

      uHat%x = 0.
      uHat%y = 1.
      uHat%z = 0.

      ! initialize arrays with zero
      outTau = 0.
      lambda = 0.
      nTau   = 0

      ! find the optical depth
      call integratePathTau(grid, aVec, uHat, nuR, nTau, outTau, lambda)
      
      write(73, *) " Optical depth from the centre to the edge of the nubula "
      write(73, *) " direction: 0,1,0 - lambda = 1.00 um"
      
      do i = 1, nTau
         write(73, *) lambda(i), outTau(i)
      end do

      write(73,*) ' '

      
      uHat%x = 0.
      uHat%y = 0.
      uHat%z = 1.

      ! initialize arrays with zero
      outTau = 0.
      lambda = 0.
      nTau   = 0

      ! 0.55um = 0.165690899

      ! find the optical depth
      call integratePathTau(grid, aVec, uHat, nuR, nTau, outTau, lambda)
      
      write(73, *) " Optical depth from the centre to the edge of the nubula "
      write(73, *) " direction: 0,0,1 - nu = 0.0911 => lambda = 1.00 um"
      
      do i = 1, nTau
         write(73, *) lambda(i), outTau(i)
      end do      

      close(73)
      
      if(associated(lambda)) deallocate(lambda)
      if(associated(outTau)) deallocate(outTau)

    end subroutine writeTau

    subroutine writeSED(grid)
      implicit none

      type(grid_type), intent(in) :: grid(*)     !

      integer :: ios, err                        ! I/O error status
      integer :: i, freq, imu, iG                 ! counters
      
      real, pointer :: SED(:,:)                  ! SED array

      real          :: lambda                    ! lambda [cm]
      real          :: totalE                    ! total energy [erg/sec]

      print*, 'in writeSED'      

      close(16)

      open(unit=16,file='output/SED.out',status='unknown', position='rewind',iostat=ios)              
      if (ios /= 0) then
         print*, "! writeSED: Cannot open file for writing"
         stop
      end if

      allocate(SED(1:nbins,0:nAngleBins), stat=err)
      if (err /= 0) then
         print*, "! writeSED: can't allocate array memory: SED"
         stop
      end if


      SED=0.

      write(16,*) 'Spectral energy distribution at the surface of the nebula: ' 
      write(16,*) '  viewPoints = ', (viewPointTheta(i), viewPointPhi(i), ' , ', i = 1, nAngleBins)
      write(16,*) '   nu [Ryd]        lambda [um]        nu*F(nu)          '
      write(16,*) '                                  [erg/sec/cm^2/str]    '

      totalE=0.

      do iG = 1, nGrids
         do freq=1,nbins

            do i = 0, grid(iG)%nCells
               do imu = 0, nAngleBins
                  SED(freq,imu)=SED(freq,imu)+grid(iG)%escapedPackets(i,freq,imu)
               end do
            end do
            
            do imu = 1, nAngleBins
               if (imu>0) then               
                  if (viewPointTheta(imu)>0.) SED(freq,imu) = SED(freq,imu)/dTheta
                  if (viewPointPhi(imu)>0.) SED(freq,imu) = SED(freq,imu)/dPhi
               else
                  if (lgSymmetricXYZ) SED(freq,imu) = SED(freq,imu)*8.
                  SED(freq,imu) = SED(freq,imu)*8./(4.*Pi)
               end if
            end do

            lambda = c/(nuArray(freq)*fr1Ryd)
            
            totalE = totalE +  SED(freq,0)
            
            SED(freq,0) = SED(freq,0)/(Pi)
            

            write(16,*) nuArray(freq), c/(nuArray(freq)*fr1Ryd)*1.e4, (SED(freq,imu)*&
                 & nuArray(freq)/widflx(freq), imu=0,nAngleBins )


         end do
      end do

      write(16,*) ' '
      if (lgSymmetricXYZ) then
         write(16,*) 'Total energy radiated out of the nebula [e36 erg/s]:', 8.*totalE
         print*, 'Total energy radiated out of the nebula [e36 erg/s]:', 8.*totalE, Lstar, nphotons
      else
         write(16,*) 'Total energy radiated out of the nebula [e36 erg/s]:', totalE
         print*, 'Total energy radiated out of the nebula [e36 erg/s]:', totalE, Lstar, nphotons
      end if
      write(16,*) 'All SEDs given per unit direction'
      write(16,*) 'To obtain total emission over all directions'
      write(16,*) 'must multiply by 4.Pi'


      close(16)
            
      if (associated(SED)) deallocate(SED)

      print*, 'out writeSED'

    end subroutine writeSED


    subroutine writeContCube(grid, freq1,freq2)
      implicit none

      type(grid_type), intent(in) :: grid(*)     

      integer :: ios, err, i,ix,iy,iz, iG        ! I/O error status, counters
      integer ::  freq, imu, ifreq1, ifreq2      ! counters
      
      real, intent(inout)         :: freq1,freq2 ! wavelengths in um
      real                        :: contI(0:nanglebins) ! continuum int in band

      print*, 'in writeContCube'      


      close(19)

      open(unit=19,file='output/contCube.out',status='unknown', position='rewind',iostat=ios)              
      if (ios /= 0) then
         print*, "! writeContCube: Cannot open file for writing"
         stop
      end if

      freq1 = c/(freq1*1.e-4*fr1Ryd)
      freq2 = c/(freq2*1.e-4*fr1Ryd)

      call locate(nuArray(1:nbins), freq1, ifreq2)
      if (ifreq2 <= 0) ifreq2=1

      call locate(nuArray(1:nbins), freq2, ifreq1)
      if (ifreq1 <= 0) ifreq1=1


      do iG = 1, nGrids
         
         do ix = 1, grid(iG)%nx
            do iy = 1, grid(iG)%ny
               do iz = 1, grid(iG)%nz

                  if ( grid(iG)%active(ix,iy,iz)>0 .or. (ig==1 .and. &
                       & ix==iorigin .and. iy==jorigin .and.iz==korigin) ) then

                     do imu=0,nanglebins
                        contI(imu)=0.
!                        do freq = ifreq1, ifreq2
                        do freq = 1, nbins
                           contI(imu) = contI(imu)+&
                                & grid(iG)%escapedPackets(grid(iG)%active(ix,iy,iz),freq,imu)
                        end do
                     
                        if (imu>0) then
                           if (viewPointTheta(imu)>0.) contI(imu) = contI(imu) / dTheta
                           if (viewPointPhi(imu)>0.) contI(imu) = contI(imu) / dPhi
                        else
                           contI(imu) = contI(imu) / (4.*Pi)
                        end if

                     end do
                  
                     write(19,*) iG, ix,iy,iz, (contI(imu), imu=0,nanglebins)

                  else

                     write(19,*) iG, ix,iy,iz, (0., imu=0,nanglebins)

                  end if

               end do
            end do
         end do

      end do      


      write(19,*) ' '
      write(19,*) 'All continuum intensities given per unit direction - must multiply column 3&
           & by 4. Pi to obtain total emission over all directions.'


      close(19)
            
      print*, 'writeContCube'

    end subroutine writeContCube

end module output_mod
