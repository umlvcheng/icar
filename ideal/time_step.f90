module time_step
	use data_structures     ! *_type  types
	use microphysics        ! mp
	use wind                ! update_winds
	use advection           ! advect
	
	implicit none
	private
	public :: step
	
contains
	
	subroutine boundary_update(curdata,dXdt)
		implicit none
		real,dimension(:,:,:), intent(inout) :: curdata
		real,dimension(:,:,:), intent(in) :: dXdt
		integer::nx,ny
		
		nx=size(curdata,1)
		ny=size(curdata,3)

		curdata(1,:,:) =curdata(1,:,:) +dXdt(:,1:ny,1)
		curdata(nx,:,:)=curdata(nx,:,:)+dXdt(:,1:ny,2)
		curdata(:,:,1) =curdata(:,:,1) +dXdt(:,1:nx,3)
		curdata(:,:,ny)=curdata(:,:,ny)+dXdt(:,1:nx,4)
	end subroutine boundary_update
	
	
	subroutine forcing_update(domain,bc)
		implicit none
		type(domain_type),intent(inout)::domain
		type(bc_type),intent(inout)::bc
		
		domain%u=domain%u+bc%dudt
		domain%v=domain%v+bc%dvdt
		domain%w=domain%w+bc%dwdt
		domain%p=domain%p+bc%dpdt
! 		dXdt for qv,qc,th are only applied to the boundarys
		call boundary_update(domain%th,bc%dthdt)
		call boundary_update(domain%qv,bc%dqvdt)
		call boundary_update(domain%cloud,bc%dqcdt)
	end subroutine forcing_update		


	subroutine apply_dt(bc,nsteps)
		implicit none
		type(bc_type), intent(inout) :: bc
		integer,intent(in)::nsteps
		
		bc%dudt  =bc%dudt/nsteps
		bc%dvdt  =bc%dvdt/nsteps
		bc%dwdt  =bc%dwdt/nsteps
		bc%dpdt  =bc%dpdt/nsteps
		bc%dthdt =bc%dthdt/nsteps
		bc%dqvdt =bc%dqvdt/nsteps
		bc%dqcdt =bc%dqcdt/nsteps
	end subroutine apply_dt
	
	
	subroutine step(domain,options,bc)
		implicit none
		type(domain_type),intent(inout)::domain
		type(bc_type),intent(inout)::bc
		type(options_type),intent(in)::options
		integer::i,ntimesteps
		real::dt,dtnext
		
		! courant condition for 3D advection... could make 3 x 1D to maximize dt? esp. w/linear wind speedups...
		dt=floor(options%dx/max(max(maxval(domain%u),maxval(domain%v)),maxval(domain%w))/3.0)
! 		pick the minimum dt from the begining or the end of the current timestep
		dtnext=floor(options%dx/max(max(maxval(bc%next_domain%u), &
										maxval(bc%next_domain%v+bc%dvdt)), &
										maxval(bc%next_domain%w+bc%dwdt))/3.0)
		dt=min(dt,dtnext)
! 		make dt an integer fraction of the full timestep
		dt=options%io_dt/ceiling(options%io_dt/dt)
! 		calcualte the number of timesteps
		ntimesteps=options%io_dt/dt
		
		call apply_dt(bc,ntimesteps)
		
		do i=1,ntimesteps
			call advect(domain,options,dt,options%dx)
			call mp(domain,options,dt)
	! 		call lsm(domain,options,dt)
	! 		call pbl(domain,options,dt)
	! 		call radiation(domain,options,dt)
			
			call forcing_update(domain,bc)
		enddo
	end subroutine step
end module time_step