      module fluid_model

      use class_four_vector
      use phys_constants, GC=>G
      use interpolate, only: interp, get_weight
      use kerr, only: kerr_metric, lnrf_frame, calc_rms, krolikc, calc_polvec
      use fluid_model_sphacc, only: sphacc_vals, init_sphacc, del_sphacc
      use fluid_model_constant, only: constant_vals, init_constant
      use fluid_model_toyjet, only: initialize_toyjet_model, del_toyjet_data, &
                                    toyjet_vals
      use fluid_model_phatdisk, only: phatdisk_vals, init_phatdisk, del_phatdisk, freq_tab
      use fluid_model_thindisk, only: thindisk_vals, init_thindisk
      use fluid_model_numdisk, only: initialize_numdisk_model, del_numdisk_data, &
           numdisk_vals
      use fluid_model_hotspot, only: hotspot_vals, init_hotspot, advance_hotspot_timestep
      use fluid_model_hotspot_schnittman, only: init_schnittman_hotspot, & 
           advance_schnittman_hotspot_timestep, schnittman_hotspot_vals
      use fluid_model_harm, only: initialize_harm_model, del_harm_data, harm_vals, &
           advance_harm_timestep
      use fluid_model_thickdisk, only: initialize_thickdisk_model, del_thickdisk_data, thickdisk_vals, &
           advance_thickdisk_timestep
      use fluid_model_mb09, only: initialize_mb09_model, del_mb09_data, mb09_vals, &
           advance_mb09_timestep
      use calc_gmin, only: calc_gmin_subroutine
      implicit none

      integer, parameter :: CONST=0,TAIL=1
      integer, parameter :: DUMMY=0,SPHACC=1,THINDISK=2,RIAF=3,HOTSPOT=4,PHATDISK=5,SCHNITTMAN=6,CONSTANT=7
      integer, parameter :: COSMOS=10,MB=11,HARM=12,TOYJET=13,NUMDISK=14,THICKDISK=15,MB09=16

      type fluid
        integer :: model, nfreq
        real :: rin
        real, dimension(:), allocatable :: rho,p,bmag
        real, dimension(:,:), allocatable :: fnu
        type (four_vector), dimension(:), allocatable :: u,b
      end type

      type source_params
!        double precision, dimension(:), allocatable :: mdot,lleddeta,mu
        double precision :: nfac,bfac,mbh,mdot,p1,p2,gmax,gminval,jetalphaval,muval
        double precision, dimension(:), allocatable :: gmin,jetalpha,mu
        integer :: type
      end type

!ultimately all source params stuff should probably go in own file / module
      interface initialize_source_params
         module procedure initialize_source_params
      end interface

      interface del_source_params
         module procedure del_source_params
      end interface
      
      interface assign_source_params
         module procedure assign_source_params
      end interface

      interface get_fluid_vars
        module procedure get_fluid_vars_single
        module procedure get_fluid_vars_arr
      end interface

      interface convert_fluid_vars
!       module procedure convert_fluid_vars_single
        module procedure convert_fluid_vars_arr
      end interface convert_fluid_vars

      interface initialize_fluid_model
        module procedure initialize_fluid_model
      end interface
 
!      interface del_fluid_model
!        module procedure del_fluid_model
!      end interface

!      interface initialize_num_fluid_model
!        module procedure initialize_num_fluid_model
!      end interface

!      interface del_num_fluid_model
!        module procedure del_num_fluid_model
!      end interface

      interface advance_fluid_timestep
         module procedure advance_fluid_timestep
      end interface

      interface load_fluid_model
        module procedure load_fluid_model
      end interface

      interface unload_fluid_model
        module procedure unload_fluid_model
      end interface unload_fluid_model

      contains

        subroutine load_fluid_model(fname,a)
        double precision, intent(in) :: a
        character(len=20), intent(in) :: fname
        if(fname=='COSMOS') then
!          call initialize_cosmos_model(a)
        elseif(fname=='MB') then
!          call intiialize_mb_model(a)
        elseif(fname=='THICKDISK') then
           call initialize_thickdisk_model(a,1)
        elseif(fname=='MB09') then
           call initialize_mb09_model(a,1)
        elseif(fname=='HARM') then
          call initialize_harm_model(a)
        elseif(fname=='SPHACC') then
           call init_sphacc()
        elseif(fname=='TOYJET') then
    !      write(6,*) 'load'
          call initialize_toyjet_model(a)
        elseif(fname=='THINDISK') then
          call init_thindisk(real(a))
        elseif(fname=='PHATDISK') then
          call init_phatdisk(real(a))
        elseif(fname=='NUMDISK') then
          call initialize_numdisk_model()
        elseif(fname=='HOTSPOT') then
           call init_hotspot()
        elseif(fname=='SCHNITTMAN') then
           call init_schnittman_hotspot()
        elseif(fname=='CONSTANT') then
           call init_constant()
        endif
        end subroutine load_fluid_model

        subroutine advance_fluid_timestep(fname,dt)
        double precision, intent(in) :: dt
        character(len=20), intent(in) :: fname
        if(fname=='COSMOS') then
!         call advance_cosmos_timestep(dt)
        elseif(fname=='MB') then
!           call advance_mb_timestep(dt)
        elseif(fname=='HARM') then
           call advance_harm_timestep(dt)
        elseif(fname=='THICKDISK') then 
           call advance_thickdisk_timestep(dt)
        elseif(fname=='MB09') then 
           call advance_mb09_timestep(dt)
        elseif(fname=='HOTSPOT') then
           call advance_hotspot_timestep(real(dt))
        elseif(fname=='SCHNITTMAN') then
           call advance_schnittman_hotspot_timestep(real(dt))
        endif
        end subroutine advance_fluid_timestep

        subroutine initialize_fluid_model(f,fname,a,nup)
        character(len=20), intent(in) :: fname
        type (fluid), intent(out) :: f
        integer, intent(in) :: nup
        double precision, intent(in) :: a
!        double precision, intent(inout) :: uin
!        write(6,*) 'init: ',nup,a,fname
        if(fname=='PHATDISK') then
           f%model=PHATDISK; f%nfreq=size(freq_tab)
           allocate(f%u(nup)); allocate(f%fnu(nup,f%nfreq))
           allocate(f%b(nup))
        else
           allocate(f%u(nup))
! rho is used to store T for thindisk...
           allocate(f%rho(nup))
           allocate(f%b(nup))
           if(fname=='THINDISK') then
              f%model=THINDISK
           elseif(fname=='NUMDISK') then
              f%model=NUMDISK
           else
              allocate(f%bmag(nup))
              allocate(f%p(nup))
 ! !      write(6,*) 'sz: ',size(f%bmag)
              if(fname=='COSMOS') then
                 f%model=COSMOS
              elseif(fname=='MB') then
                 f%model=MB
              elseif(fname=='HARM') then
                 f%model=HARM
              elseif(fname=='THICKDISK') then
                 f%model=THICKDISK
              elseif(fname=='MB09') then
                 f%model=MB09
              elseif(fname=='TOYJET') then
                 f%model=TOYJET
              elseif(fname=='SPHACC') then
                 f%model=SPHACC
              elseif(fname=='RIAF') then
                 f%model=RIAF
              elseif(fname=='HOTSPOT') then
                 f%model=HOTSPOT
              elseif(fname=='SCHNITTMAN') then
                 f%model=SCHNITTMAN
              elseif(fname=='CONSTANT') then
                 f%model=CONSTANT
              else
                 write(6,*) 'WARNING: Unsupported fluid model -- using DUMMY'
                 f%model=DUMMY
              endif
           endif
        endif
!        f%model=model
!  !      write(6,*) 'fm: ',f%model, NUM_MODEL
!        if(f%model.gt.NUM_MODEL) call initialize_num_fluid_model(f,a)
        end subroutine initialize_fluid_model
 
!        subroutine initialize_num_fluid_model(f,a)
!        double precision, intent(in) :: a
!        type (fluid), intent(inout) :: f
!  !      write(6,*) 'fnm: ',f%model
!        SELECT CASE (f%model)
!          CASE (COSMOS)
!            call initialize_cosmos_model(f)
!          CASE (MB)
!            call initialize_mb_model(f)
!          CASE (HARM) 
!            call initialize_harm_model(f)
!          CASE (TOYJET)
!      !      write(6,*) 'made it',f%model
!            call initialize_toyjet_model(f,a)
!        END SELECT
!        end subroutine initialize_num_fluid_model

!        subroutine del_num_fluid_model(f)
!        type (fluid), intent(inout) :: f
!        call del_fluid_data
!        end subroutine del_num_fluid_model

        subroutine unload_fluid_model(fname)
        character(len=20), intent(in) :: fname
        if(fname=='COSMOS') then
!          call initialize_cosmos_model(a)
        elseif(fname=='MB') then
!          call intiialize_mb_model(a)
        elseif(fname=='HARM') then
           call del_harm_data()
        elseif(fname=='THICKDISK') then
           call del_thickdisk_data()
        elseif(fname=='MB09') then
           call del_mb09_data()
        elseif(fname=='TOYJET') then
    !      write(6,*) 'load'
           call del_toyjet_data()
        elseif(fname=='PHATDISK') then
           call del_phatdisk()
        elseif(fname=='NUMDISK') then
           call del_numdisk_data()
        elseif(fname=='SPHACC') then
           call del_sphacc()
        endif
        end subroutine unload_fluid_model

        subroutine del_fluid_model(f)
        type (fluid), intent(inout) :: f
        if(f%model==PHATDISK) then
           deallocate(f%u); deallocate(f%fnu)
           deallocate(f%b)
        else
           deallocate(f%u); deallocate(f%rho); deallocate(f%b)
!           write(6,*) 'del_fluid: ',f%model,THINDISK
           if(f%model.ne.THINDISK.and.f%model.ne.NUMDISK) then
              deallocate(f%p)
              deallocate(f%bmag)
           endif
        endif
        f%model=-1
        end subroutine del_fluid_model
       
        subroutine get_fluid_vars_single(x0,k0,a,f)
        type (four_vector), intent(in) :: x0, k0
        type (fluid), intent(inout) :: f
        double precision, intent(in) :: a
 ! !      write(6,*) 'fluid: ',size(x0),f%model
        SELECT CASE(f%model)
          CASE (SPHACC)
!            call get_sphacc_fluidvars(x0,f)
          CASE (TOYJET)
!      !      write(6,*) 'made it'
!            call get_toyjet_fluidvars(x0,real(a),f)
          CASE (THINDISK)
!            call initialize_thindisk_model(f)
          CASE (HOTSPOT) 
!            call initialize_hotspot_model(f)
          CASE (RIAF)
!            call initialize_toyjet_model(f)
          CASE (DUMMY)
        END SELECT
        end subroutine get_fluid_vars_single

        subroutine get_fluid_vars_arr(x0,k0,a,f)
        type (four_vector), intent(in), dimension(:) :: x0, k0
        type (fluid), intent(inout) :: f
        double precision, intent(in) :: a
 ! !      write(6,*) 'fluid: ',size(x0),f%model
        SELECT CASE(f%model)
          CASE (SPHACC)
            call get_sphacc_fluidvars(x0,f)
          CASE (TOYJET)
      !      write(6,*) 'made it'
            call get_toyjet_fluidvars(x0,real(a),f)
          CASE (THINDISK)
            call get_thindisk_fluidvars(x0,k0,real(a),f)
          CASE (PHATDISK)
            call get_phat_fluidvars(x0,k0,real(a),f)
          CASE (NUMDISK)
            call get_numdisk_fluidvars(x0,k0,real(a),f)
          CASE (HOTSPOT)
            call get_hotspot_fluidvars(x0,real(a),f)
          CASE (SCHNITTMAN)
            call get_schnittman_hotspot_fluidvars(x0,real(a),f)
          CASE (HARM)
             call get_harm_fluidvars(x0,real(a),f)
          CASE (THICKDISK)
             call get_thickdisk_fluidvars(x0,real(a),f)
          CASE (MB09)
             call get_mb09_fluidvars(x0,real(a),f)
!          CASE (RIAF)
!            call initialize_toyjet_model(f)
          CASE (CONSTANT)
             call get_constant_fluidvars(x0,real(a),f)
          CASE (DUMMY)
        END SELECT
        end subroutine get_fluid_vars_arr

        subroutine convert_fluid_vars_arr(f,ncgs,ncgsnth,bcgs,tcgs,fnuvals,freqvals,sp)
        type (fluid), intent(in) :: f
        type (source_params), intent(inout) :: sp
        double precision, intent(out), dimension(size(f%rho)) :: ncgs,ncgsnth,bcgs,tcgs
        double precision, intent(out), dimension(:), allocatable :: freqvals
        double precision, intent(out), dimension(:,:), allocatable :: fnuvals
!        write(6,*) 'fluid convert: ',f%model,size(bcgs)
        SELECT CASE(f%model)
          CASE (SPHACC)
            call convert_fluidvars_sphacc(f,ncgs,ncgsnth,bcgs,tcgs,sp)
          CASE (TOYJET)
            call convert_fluidvars_toyjet(f,ncgs,ncgsnth,bcgs,tcgs,sp)
          CASE (THINDISK)
            call convert_fluidvars_thindisk(f,tcgs,ncgs)
          CASE(PHATDISK)
             call convert_fluidvars_phatdisk(f,fnuvals,freqvals)
          CASE(NUMDISK)
             call convert_fluidvars_numdisk(f,tcgs,ncgs)
          CASE (HOTSPOT)
            call convert_fluidvars_hotspot(f,ncgs,ncgsnth,bcgs,tcgs,sp)
          CASE (SCHNITTMAN)
            call convert_fluidvars_schnittman_hotspot(f,ncgs,ncgsnth,bcgs,tcgs,sp)
          CASE (HARM)
             call convert_fluidvars_harm(f,ncgs,ncgsnth,bcgs,tcgs,sp)
          CASE (THICKDISK)
             call convert_fluidvars_thickdisk(f,ncgs,ncgsnth,bcgs,tcgs,sp)
          CASE (MB09)
             call convert_fluidvars_mb09(f,ncgs,ncgsnth,bcgs,tcgs,sp)
          CASE (CONSTANT)
             call convert_fluidvars_constant(f,ncgs,ncgsnth,bcgs,tcgs,sp)
!          CASE (RIAF)
!            call initialize_toyjet_model(f)
!          CASE (DUMMY)
        END SELECT
! call source_params stuff here?
        call assign_source_params(sp,ncgs,tcgs,ncgsnth)
!        write(6,*) 'after convert'
        end subroutine convert_fluid_vars_arr

        subroutine get_thindisk_fluidvars(x0,k0,a,f)
        type (four_vector), intent(in), dimension(:) :: x0, k0
        type (fluid), intent(inout) :: f
        real, intent(in) :: a
!        real :: rms,T0
        real, dimension(size(x0)) :: T,omega
        real, dimension(size(x0),10) :: metric
        call thindisk_vals(real(x0%data(2)),real(x0%data(3)),a,T,omega)
        f%rho=T
!        write(6,*) 'get fluidvars: ',size(f%rho), size(T)
        f%u%data(2)=0.; f%u%data(3)=0.
        f%b%data(1)=0.; f%b%data(2)=0.; f%b%data(3)=0.; f%b%data(4)=0.
!        write(6,*) 't: ',T,f%u%data(4),om,1./(r**3./2.+a),a*(r*r+a*a-d)/ &
        !  ((r*r+a*a)**2.-d*a*a*sin(x0%data(3))**2.)
        metric=kerr_metric(real(x0%data(2)),real(x0%data(3)),a)
!        f%b%data(2)=cos(x0%data(4))/metric(:,5)
!        f%b%data(4)=-sin(x0%data(4))/metric(:,10)
!        call assign_metric(f%b,transpose(metric))
        call assign_metric(f%u,transpose(metric))
        call assign_metric(f%b,transpose(metric))
        f%u%data(1)=sqrt(-1./(metric(:,1)+2.*metric(:,4)*omega+metric(:,10)* &
         omega*omega))
        f%u%data(4)=omega*f%u%data(1)
! Assign normal vector as magnetic field for comoving_ortho:
         f%b = calc_polvec(x0%data(2),cos(x0%data(3)),k0,dble(a),asin(1d0))
!         f%b%data(1)=-f%b%data(1)
!         f%b%data(2)=-f%b%data(2)
!         f%b%data(3)=-f%b%data(3)
!         f%b%data(4)=-f%b%data(4)
!        write(6,*) 'udotu: ',f%u*f%u,omega,f%u%data(1),r,rms
 !       write(6,*) 'thindisk fluidvars: ',allocated(f%u), &
!             allocated(f%b), allocated(f%rho)
        end subroutine get_thindisk_fluidvars

        subroutine get_numdisk_fluidvars(x0,k0,a,f)
        type (four_vector), intent(in), dimension(:) :: x0, k0
        type (fluid), intent(inout) :: f
        real, intent(in) :: a
!        real :: rms,T0
        real, dimension(size(x0)) :: T,omega,phi
        real, dimension(size(x0),10) :: metric
        phi=x0%data(4); phi=phi+12.*acos(-1.)
        phi=mod(phi,(2.*acos(-1.)))
!        write(6,*) 'numdisk phi: ',minval(phi),maxval(phi)
        call numdisk_vals(real(x0%data(2)),phi,a,T,omega)
        f%rho=T
!        write(6,*) 'get fluidvars: ',size(f%rho), size(T)
        f%u%data(2)=0.; f%u%data(3)=0.
        f%b%data(1)=0.; f%b%data(2)=0.; f%b%data(3)=0.; f%b%data(4)=0.
!        write(6,*) 't: ',T,f%u%data(4),om,1./(r**3./2.+a),a*(r*r+a*a-d)/ &
        !  ((r*r+a*a)**2.-d*a*a*sin(x0%data(3))**2.)
        metric=kerr_metric(real(x0%data(2)),real(x0%data(3)),a)
        f%b%data(2)=cos(x0%data(4))/metric(:,5)
        f%b%data(4)=-sin(x0%data(4))/metric(:,10)
!        call assign_metric(f%b,transpose(metric))
        call assign_metric(f%u,transpose(metric))
        call assign_metric(f%b,transpose(metric))
        f%u%data(1)=sqrt(-1./(metric(:,1)+2.*metric(:,4)*omega+metric(:,10)* &
         omega*omega))
        f%u%data(4)=omega*f%u%data(1)
        f%b = calc_polvec(x0%data(2),cos(x0%data(3)),k0,dble(a),0.d0)
!        write(6,*) 'udotu: ',f%u*f%u,omega,f%u%data(1),r,rms
 !       write(6,*) 'numdisk fluidvars: ',allocated(f%u), &
!             allocated(f%b), allocated(f%rho)
        end subroutine get_numdisk_fluidvars

        subroutine get_phat_fluidvars(x0,k0,a,f)
        type (four_vector), intent(in), dimension(:) :: x0, k0
        type (fluid), intent(inout) :: f
        real, intent(in) :: a
!        real :: rms,T0
        real, dimension(size(x0)) :: omega
        real, dimension(size(x0),10) :: metric
        real, dimension(size(x0),size(freq_tab)) :: fnu
!        write(6,*) 'phatdisk vals', size(x0%data(2))
        call phatdisk_vals(real(x0%data(2)),a,fnu,omega)
        f%fnu=fnu
        f%u%data(2)=0.; f%u%data(3)=0.
        f%b%data(1)=0.; f%b%data(2)=0.; f%b%data(3)=0.; f%b%data(4)=0.
!        write(6,*) 't: ',T,f%u%data(4),om,1./(r**3./2.+a),a*(r*r+a*a-d)/ &
        !  ((r*r+a*a)**2.-d*a*a*sin(x0%data(3))**2.)
        metric=kerr_metric(real(x0%data(2)),real(x0%data(3)),a)
!        call assign_metric(f%b,transpose(metric))
        call assign_metric(f%u,transpose(metric))
        f%u%data(1)=sqrt(-1./(metric(:,1)+2.*metric(:,4)*omega+metric(:,10)* &
         omega*omega))
        f%u%data(4)=omega*f%u%data(1)
        f%b = calc_polvec(x0%data(2),cos(x0%data(3)),k0,dble(a),0.d0)
!        write(6,*) 'udotu: ',f%u*f%u,omega,f%u%data(1),r,rms
        end subroutine get_phat_fluidvars

        subroutine get_toyjet_fluidvars(x0,a,f)
        type (four_Vector), intent(in), dimension(:) :: x0
        real, intent(in) :: a
        type (fluid), intent(inout) :: f
        ! Computes properties of jet solution from Broderick & Loeb (2009)
        ! JAD 4/23/2010, fortran 3/30/2011
        call toyjet_vals(x0,a,f%rho,f%p,f%b,f%u,f%bmag)
!        write(6,*) 'toyjet u: ',f%u*f%u, f%b*f%b
        end subroutine get_toyjet_fluidvars

        subroutine get_harm_fluidvars(x0,a,f)
        type (four_Vector), intent(in), dimension(:) :: x0
        real, intent(in) :: a
        type (fluid), intent(inout) :: f
        ! Computes properties of jet solution from Broderick & Loeb (2009)
        ! JAD 4/23/2010, fortran 3/30/2011
        call harm_vals(x0,a,f%rho,f%p,f%b,f%u,f%bmag)
!        write(6,*) 'harm u: ',f%u*f%u, f%b*f%b
        end subroutine get_harm_fluidvars

        subroutine get_thickdisk_fluidvars(x0,a,f)
        type (four_Vector), intent(in), dimension(:) :: x0
        real, intent(in) :: a
        type (fluid), intent(inout) :: f
        ! Computes properties of jet solution from Broderick & Loeb (2009)
        ! JAD 4/23/2010, fortran 3/30/2011
        call thickdisk_vals(x0,a,f%rho,f%p,f%b,f%u,f%bmag)
!        write(6,*) 'thickdisk u: ',f%u*f%u, f%b*f%b
        end subroutine get_thickdisk_fluidvars

        subroutine get_mb09_fluidvars(x0,a,f)
        type (four_Vector), intent(in), dimension(:) :: x0
        real, intent(in) :: a
        type (fluid), intent(inout) :: f
        ! Computes properties of jet solution from Broderick & Loeb (2009)
        ! JAD 4/23/2010, fortran 3/30/2011
        call mb09_vals(x0,a,f%rho,f%p,f%b,f%u,f%bmag)
!        write(6,*) 'mb09 u: ',f%u*f%u, f%b*f%b
        end subroutine get_mb09_fluidvars

        subroutine convert_fluidvars_thickdisk(f,ncgs,ncgsnth,bcgs,tempcgs,sp)
        type (fluid), intent(in) :: f
        type (source_params), intent(in) :: sp
        double precision, dimension(size(f%rho)), intent(out) :: ncgs,ncgsnth,bcgs,tempcgs
        double precision, dimension(size(f%rho)) :: rhocgs,pcgs
        double precision :: lcgs,tcgs,mdot
        ! Converts Cosmos++ code units to standard cgs units. Follows Schnittman et al. (2006).
        ! JAD 11/26/2012 adapted from IDL code
        ! Black hole mass sets time and length scales:
!        write(6,*) 'convert mbh: ',sp%mbh
        lcgs=GC*sp%mbh*msun/c**2; tcgs=lcgs/c
!        write(6,*) 'lcgs: ',lcgs,tcgs
        ! Typical mb09 code mdot value. (not even close for thickdisk but for comparison to IDL purposes JAD 1/11/2013)
        mdot=.0013
        ! Now convert density using black hole to scale length/time, 
        ! accretion rate to scale torus mass:
!        write(6,*) 'convert mdot: ',mdot,sp%mdot
        rhocgs=sp%mdot/mdot/lcgs**3*tcgs*f%rho; ncgs=rhocgs/mp
!        write(6,*) 'n: ',sp%mdot/mdot/lcgs**3.*tcgs/mp
        ! Use this to convert pressure:
        pcgs=f%p*rhocgs/f%rho*c**2.
        ! Ideal gas temperature for single fluid (i.e., no separate e-/p):
        tempcgs=pcgs/ncgs/k
        ! And finally, bfield conversion is just square root of this:
        bcgs=f%bmag*sqrt(rhocgs/f%rho)*c
        ! Convert HL units to cgs:
        bcgs=bcgs*sqrt(4.*pi)
        ! non-thermal particles from n ~ b^2 / \rho
        where(f%bmag**2./f%rho.gt.1.)
           ncgsnth=sp%jetalpha*bcgs**2./8./pi/sp%gmin*(sp%p1-2.)/(sp%p1-1.)/8.2e-7
        elsewhere
           ncgsnth=0.
        endwhere
!        write(6,*) 'leaving convert', maxval(bcgs), maxval(ncgs), maxval(tempcgs)
!        write(6,*) 'convert b: ',bcgs
!        write(6,*) 'convert n: ',ncgs/1e7
!        write(6,*) 'convert temp: ',tempcgs/1e10
!        write(6,*) 'convert temp 2: ',f%p/f%rho*mp/k*c**2./1e10
!        write(6,*) 'convert mdot: ',sp%mdot, sp%mbh
!        write(6,*) 'convert bh: ',tcgs,lcgs
        end subroutine convert_fluidvars_thickdisk

        subroutine convert_fluidvars_mb09(f,ncgs,ncgsnth,bcgs,tempcgs,sp)
        type (fluid), intent(in) :: f
        type (source_params), intent(in) :: sp
        double precision, dimension(size(f%rho)), intent(out) :: ncgs,ncgsnth,bcgs,tempcgs
        double precision, dimension(size(f%rho)) :: rhocgs,pcgs
        double precision :: lcgs,tcgs,mdot
        ! Converts Cosmos++ code units to standard cgs units. Follows Schnittman et al. (2006).
        ! JAD 11/26/2012 adapted from IDL code
        ! Black hole mass sets time and length scales:
!        write(6,*) 'convert mbh: ',sp%mbh
        lcgs=GC*sp%mbh*msun/c**2; tcgs=lcgs/c
!        write(6,*) 'lcgs: ',lcgs,tcgs
        ! Typical mb09 code mdot value. (not even close for mb09 but for comparison to IDL purposes JAD 1/11/2013)
        mdot=.0013
        ! Now convert density using black hole to scale length/time, 
        ! accretion rate to scale torus mass:
!        write(6,*) 'convert mdot: ',mdot,sp%mdot
        rhocgs=sp%mdot/mdot/lcgs**3*tcgs*f%rho; ncgs=rhocgs/mp
!        write(6,*) 'n: ',sp%mdot/mdot/lcgs**3.*tcgs/mp
        ! Use this to convert pressure:
        pcgs=f%p*rhocgs/f%rho*c**2.
        ! Ideal gas temperature for single fluid (i.e., no separate e-/p):
        tempcgs=pcgs/ncgs/k
        ! And finally, bfield conversion is just square root of this:
        bcgs=f%bmag*sqrt(rhocgs/f%rho)*c
        ! Convert HL units to cgs:
        bcgs=bcgs*sqrt(4.*pi)
!        write(6,*) 'leaving convert', maxval(bcgs), maxval(ncgs), maxval(tempcgs)
!        write(6,*) 'convert b: ',bcgs
!        write(6,*) 'convert n: ',ncgs/1e7
!        write(6,*) 'convert temp: ',tempcgs/1e10
!        write(6,*) 'convert temp 2: ',f%p/f%rho*mp/k*c**2./1e10
!        write(6,*) 'convert mdot: ',sp%mdot, sp%mbh
!        write(6,*) 'convert bh: ',tcgs,lcgs
        end subroutine convert_fluidvars_mb09

        subroutine convert_fluidvars_harm(f,ncgs,ncgsnth,bcgs,tempcgs,sp)
        type (fluid), intent(in) :: f
        type (source_params), intent(in) :: sp
        double precision, dimension(size(f%rho)), intent(out) :: ncgs,ncgsnth,bcgs,tempcgs
        double precision, dimension(size(f%rho)) :: rhocgs,pcgs
        double precision :: lcgs,tcgs,mdot
        ! Converts Cosmos++ code units to standard cgs units. Follows Schnittman et al. (2006).
        ! JAD 11/26/2012 adapted from IDL code
        ! Black hole mass sets time and length scales:
!        write(6,*) 'convert mbh: ',sp%mbh
        lcgs=GC*sp%mbh*msun/c**2; tcgs=lcgs/c
!        write(6,*) 'lcgs: ',lcgs,tcgs
        ! Typical mb09 code mdot value.
        mdot=.003
        ! Now convert density using black hole to scale length/time, 
        ! accretion rate to scale torus mass:
!        write(6,*) 'convert mdot: ',mdot,sp%mdot
        rhocgs=sp%mdot/mdot/lcgs**3*tcgs*f%rho; ncgs=rhocgs/mp
!        write(6,*) 'n: ',sp%mdot/mdot/lcgs**3.*tcgs/mp
        ! Use this to convert pressure:
        pcgs=f%p*rhocgs/f%rho*c**2.
        ! Ideal gas temperature for single fluid (i.e., no separate e-/p):
        tempcgs=pcgs/ncgs/k
        ! And finally, bfield conversion is just square root of this:
        bcgs=f%bmag*sqrt(rhocgs/f%rho)*c
        ! Convert HL units to cgs:
        bcgs=bcgs*sqrt(4.*pi)
        ! non-thermal e- put in by hand
        ncgsnth=ncgs
!        write(6,*) 'leaving convert', maxval(bcgs), maxval(ncgs), maxval(tempcgs)
!        write(6,*) 'convert b: ',bcgs
!        write(6,*) 'convert n: ',ncgs/1e7
!        write(6,*) 'convert temp: ',tempcgs/1e10
!        write(6,*) 'convert temp 2: ',f%p/f%rho*mp/k*c**2./1e10
!        write(6,*) 'convert mdot: ',sp%mdot, sp%mbh
!        write(6,*) 'convert bh: ',tcgs,lcgs
        end subroutine convert_fluidvars_harm

        subroutine convert_fluidvars_toyjet(f,ncgs,ncgsnth,bcgs,tcgs,sp)
        type (fluid), intent(in) :: f
        double precision, dimension(size(f%rho)), &
          intent(out) :: ncgs,ncgsnth,bcgs,tcgs
        type (source_params), intent(in) :: sp
        !real :: bfac=70., nfac=2.
!        write(6,*) 'sp: ',sp%nfac, sp%bfac
        ncgsnth=f%rho*sp%nfac; bcgs=f%bmag*sp%bfac; ncgs=0.; tcgs=0.
        end subroutine convert_fluidvars_toyjet

        subroutine convert_fluidvars_hotspot(f,ncgs,ncgsnth,bcgs,tcgs,sp)
        type (fluid), intent(in) :: f
        double precision, dimension(size(f%rho)), &
          intent(out) :: ncgs,ncgsnth,bcgs,tcgs
        type (source_params), intent(in) :: sp
        ncgs=f%rho; bcgs=f%bmag
        end subroutine convert_fluidvars_hotspot

        subroutine convert_fluidvars_schnittman_hotspot(f,ncgs,ncgsnth,bcgs,tcgs,sp)
        type (fluid), intent(in) :: f
        double precision, dimension(size(f%rho)), &
          intent(out) :: ncgs,ncgsnth,bcgs,tcgs
        type (source_params), intent(in) :: sp
        ncgs=f%rho; bcgs=1d0
        end subroutine convert_fluidvars_schnittman_hotspot

        subroutine convert_fluidvars_thindisk(f,tcgs,ncgs)
        type (fluid), intent(in) :: f
        double precision, dimension(size(f%rho)), intent(out) :: tcgs,ncgs
!        write(6,*) 'convert thindisk: ',size(f%rho),size(ncgs),size(tcgs)
        tcgs=f%rho
        ncgs=1.
        end subroutine convert_fluidvars_thindisk

        subroutine convert_fluidvars_numdisk(f,tcgs,ncgs)
        type (fluid), intent(in) :: f
        double precision, dimension(size(f%rho)), intent(out) :: tcgs,ncgs
!        write(6,*) 'convert numdisk: ',size(f%rho),size(ncgs),size(tcgs)
        tcgs=f%rho
        ncgs=1.
        end subroutine convert_fluidvars_numdisk

        subroutine convert_fluidvars_phatdisk(f,fnu,nu)
        type (fluid), intent(in) :: f
        double precision, dimension(:,:), allocatable, intent(out) :: fnu
        double precision, dimension(:), allocatable, intent(out) :: nu
        allocate(fnu(size(f%fnu,1),size(f%fnu,2)))
        allocate(nu(size(freq_tab)))
        fnu=f%fnu; nu=freq_tab
        end subroutine convert_fluidvars_phatdisk

        subroutine get_sphacc_fluidvars(x0,f)
        type (four_vector), intent(in), dimension(:) :: x0
        type (fluid), intent(inout) :: f
        real, dimension(size(x0)) :: u,grr,g00,n,B,T,ur
        u=1./x0%data(2)
        call sphacc_vals(u,n,B,T,ur)
       ! Equipartition B field
!        write(6,*) 'sphacc: ',B,size(x0)
        g00=-(1.-2.*u)
        grr=-1d0/g00
        f%u%data(2)=-ur
        f%u%data(3)=0d0
        f%u%data(4)=0d0
!        write(6,*) 'sphacc u: '!,-(grr*f%u%data(2)*f%u%data(2)+1)/g00
        f%u%data(1)=sqrt((-grr*f%u%data(2)*f%u%data(2)-1)/g00)
        f%b%data(3)=0d0
        f%b%data(4)=0d0
! use u dot b = 0, b dot b = B^2 to get components:
        f%b%data(1)=sqrt(f%u%data(2)**2*grr*B**2/ &
        (f%u%data(2)**2*g00*grr+f%u%data(1)**2*g00*g00))
        f%b%data(2)=-sqrt(B**2/grr-f%b%data(1)**2*g00/grr)
        f%rho=n
        f%p=T
        f%bmag=B
!        write(6,*) 'after sphacc u'
!        write(6,'((E9.4,2X))') u
 !       write(6,*) 'T'
 !       write(6,'((E9.4,2X))') T
 !       write(6,*) 'n'
 !       write(6,'((E9.4,2X))') n
 !       write(6,*) 'B'
 !       write(6,'((E9.4,2X))') B
        end subroutine get_sphacc_fluidvars

        subroutine convert_fluidvars_sphacc(f,ncgs,ncgsnth,bcgs,tcgs,sp)
        type (fluid), intent(in) :: f
        type (source_params), intent(in) :: sp
        double precision, dimension(size(f%rho)),  &
          intent(inout) :: ncgs,ncgsnth,bcgs,tcgs
!        write(6,*) 'convert', size(f%rho),size(ncgs)
!        write(6,*) 'convert',size(bcgs),size(tcgs)
!        write(6,*) 'convert',size(f%rho),size(f%bmag),size(f%p)
        ncgs=f%rho; bcgs=f%bmag; tcgs=f%p; ncgsnth=0.
!        write(6,*) 'after convert'
        end subroutine convert_fluidvars_sphacc

        subroutine get_hotspot_fluidvars(x0,a,f)
        type (fluid), intent(inout) :: f
        real, intent(in) :: a
        type (four_vector), intent(in), dimension(:) :: x0
        type (four_Vector), dimension(size(x0)) :: x, xout
        real, dimension(size(x0)) :: n
        x=x0
! transform geodesic phi, t
        x%data(4) = -1*acos(0.) - x%data(4)
        x%data(1) = -1.*x%data(1)
!        write(6,*) 't hotspot: ',x%data(1)
        call hotspot_vals(x,a,n,f%b,f%u,xout)
        f%rho = dble(n)
        f%bmag = sqrt(f%b*f%b)
        end subroutine get_hotspot_fluidvars
        
        subroutine get_constant_fluidvars(x0,a,f)
        type (fluid), intent(inout) :: f
        real, intent(in) :: a
        type (four_vector), dimension(:), intent(in) :: x0
        real, dimension(size(x0)) :: u,n,B,T
        u = 1./x0%data(2)
        call constant_vals(u,n,B,T)
        f%rho = dble(n)
        f%bmag = B
        f%p = T
! magnetic field direction
        f%u = 0.
        end subroutine get_constant_fluidvars

        subroutine get_schnittman_hotspot_fluidvars(x0,a,f)
        type (fluid), intent(inout) :: f
        real, intent(in) :: a
        type (four_vector), intent(in), dimension(:) :: x0
        type (four_Vector), dimension(size(x0)) :: x, xout
        real, dimension(size(x0),10) :: metric
        real, dimension(size(x0)) :: n,omega,gfac,omt,ut,lc,hc,om,ar,d,safe
        real :: rms
        call schnittman_hotspot_vals(x0,a,n)
        !write(6,*) 'schnittman hotspot vars: ',n
        omega=1./(x0%data(2)**(3./2.)+a)
        f%rho = dble(n)
        f%u%data(2)=0.; f%u%data(3)=0.
        f%b%data(1)=0.; f%b%data(2)=0.; f%b%data(3)=0.; f%b%data(4)=0.
        metric=kerr_metric(real(x0%data(2)),real(x0%data(3)),a)
        f%u%data(1)=sqrt(-1./(metric(:,1)+2.*metric(:,4)*omega+metric(:,10)* &
         omega*omega))
        f%u%data(4)=omega*f%u%data(1)
        rms=calc_rms(a)
        d=x0%data(2)*x0%data(2)-2.*x0%data(2)+a*a
        lc=(rms*rms-2.*a*sqrt(rms)+a*a)/(rms**1.5-2.*sqrt(rms)+a)
        hc=(2.*x0%data(2)-a*lc)/d
        ar=(x0%data(2)*x0%data(2)+a*a)**2.-a*a*d*sin(x0%data(3))**2.
        om=2.*a*x0%data(2)/ar
        where(x0%data(2).gt.rms)
           omt=max(1./(x0%data(2)**(3./2.)+a),om)
        elsewhere
           omt=max((lc+a*hc)/(x0%data(2)*x0%data(2)+2.*x0%data(2)*(1.+hc)),om)
        endwhere
!        write(6,*) 'fluid hotspot assign xspot', omega, tspot, r0spot
        ut=sqrt(-1./(metric(:,1)+2.*metric(:,4)*omt+metric(:,10)* &
         omt*omt))
        safe=metric(:,1)+2.*metric(:,4)*omega+metric(:,10)* &
             omega*omega
        f%u%data(1)=merge(f%u%data(1),dble(ut),safe.lt.0d0)
        f%u%data(4)=merge(f%u%data(4),omt*f%u%data(1),safe.lt.0d0)
!        write(6,*) 'schnittman u safe: ',safe
!        write(6,*) 'schnittman u omt: ',omt
!        write(6,*) 'schnittman ut: ',f%u%data(1)
        gfac=1d0/sqrt((metric(:,10)*metric(:,1)-metric(:,4)*metric(:,4))* & 
           (metric(:,10)*f%u%data(4)*f%u%data(4)+f%u%data(1)* & 
           (2d0*metric(:,4)*f%u%data(4)+metric(:,1)*f%u%data(1))))
        f%b%data(1)=gfac*abs(metric(:,10)*f%u%data(4)+metric(:,4)*f%u%data(1))
        f%b%data(4)=-sign(1d0,metric(:,10)*f%u%data(4)+metric(:,4)*f%u%data(1)) &
           *(f%u%data(1)*metric(:,1)+metric(:,4)*f%u%data(4))*gfac
        call assign_metric(f%b,transpose(metric))
        call assign_metric(f%u,transpose(metric))
! Toroidal magnetic field:
        f%bmag = sqrt(f%b*f%b)
!        write(6,*) 'schnittman bmag u*u: ',f%u*f%u,f%bmag
        end subroutine get_schnittman_hotspot_fluidvars

        subroutine convert_fluidvars_constant(f,ncgs,ncgsnth,bcgs,tcgs,sp)
        type (fluid), intent(in) :: f
        double precision, dimension(size(f%rho)), &
          intent(out) :: ncgs,ncgsnth,bcgs,tcgs
        type (source_params), intent(in) :: sp
        ncgs=f%rho; bcgs=f%bmag; ncgsnth=f%rho
        tcgs=f%p
        end subroutine convert_fluidvars_constant

! source param routines
        subroutine assign_source_params_type(sp,type)
          character(len=20), intent(in) :: type
          type (source_params), intent(inout) :: sp
          if(type=='const') then
             sp%type=CONST
          elseif(type=='tail') then
             sp%type=TAIL
          else
             write(6,*) 'ERROR in assign_source_params_type: type not recognized', type
          endif
        end subroutine assign_source_params_type

        subroutine initialize_source_params(sp,nup)
          type (source_params), intent(inout) :: sp
          integer, intent(in) :: nup
          allocate(sp%gmin(nup))
          allocate(sp%jetalpha(nup))
          allocate(sp%mu(nup))
        end subroutine initialize_source_params

        subroutine del_source_params(sp)
          type (source_params), intent(inout) :: sp
          deallocate(sp%gmin)
          deallocate(sp%jetalpha)
          deallocate(sp%mu)
        end subroutine del_source_params
        
        subroutine assign_source_params(sp,ncgs,tcgs,ncgsnth)
          type (source_params), intent(inout) :: sp
          double precision, dimension(:), intent(in) :: ncgs,tcgs
          double precision, dimension(:), intent(inout) :: ncgsnth
          double precision, dimension(size(ncgs)) :: x,one,gmin,gmax,zero
          zero=0d0
          one=1d0
          gmax=sp%gmax
          select case(sp%type)
             case (CONST)
                sp%gmin=sp%gminval
                sp%jetalpha=sp%jetalphaval
                sp%mu=sp%muval
             case (TAIL)
                sp%jetalpha=sp%jetalphaval
                sp%mu=sp%muval
                call calc_gmin_subroutine(sp%p2,k*tcgs/m/c/c,sp%jetalpha,gmin,x)
                sp%gmin=merge(merge(gmin,one,gmin.ge.1d0),gmax/2d0,gmin.le.gmax)
                ncgsnth=merge(x*ncgs*sp%gmin**(1.-sp%p2),zero,x.gt.0d0)
!                sp%gmin=gmin
!                where(ncgsnth.ne.ncgsnth)
!                   ncgsnth=-1e8
!                endwhere
!                write(6,*) 'gmin ncgsnth tail: ',minval(sp%gmin),maxval(sp%gmin),minval(ncgsnth),maxval(ncgsnth)
!                write(6,*) 'gmin ncgsnth tail: ',gmin
!                write(6,*) 'gmin ncgsnth tail x: ',x
!                write(6,*) 'gmin ncgsnth tail: ',ncgs
!                write(6,*) 'gmin ncgsnth tail: ',ncgsnth
          end select
        end subroutine assign_source_params

      end module fluid_model
