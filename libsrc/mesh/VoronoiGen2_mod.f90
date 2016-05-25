module VoronoiGen2_mod

  use dc_types
  use dc_message, only: &
       & MessageNotify

  use VectorSpace_mod
  use geometry2D_mod
  use SphericalCoord_mod
  use PolyMesh_mod

  implicit none
  private

  integer :: vorVxNum
  integer :: siteNum
  integer, allocatable :: vrVxvrVxG(:,:)
  integer, allocatable :: vrVxvrRCG(:,:)
  logical, allocatable :: isAddedSite(:)
  real(DP), allocatable :: vrVxRadius(:)
  type(Vector2d), allocatable :: vrVxPos(:)
  
  integer :: currentVrVxNum

  type :: vrRegion
     integer, pointer :: vertIds(:) => null()
  end type vrRegion

  type(vrRegion), allocatable :: vrRegionList(:)


  public :: Voronoi2Gen_Init, Voronoi2Gen_Final
  public :: Voronoi2DiagramGen
  
  public :: Voronoi2_SetTopology, GetVrRegionPoints
  public :: search_VrRegionContainedPt

  character(*), parameter :: module_name = "SVoronoiGen2_mod"

contains
subroutine Voronoi2Gen_Init(generatorsNum)
  integer, intent(in) :: generatorsNum

  siteNum = generatorsNum
  vorVxNum = 2*siteNum! - 4 

  allocate(vrVxRadius(vorVxNum))
  allocate(vrVxvrVXG(3,vorVxNum))
  allocate(vrVxvrRCG(3,vorVxNum))
  allocate(vrVxPos(vorVxNum))
  allocate(isAddedSite(siteNum))
  allocate(vrRegionList(siteNum))

end subroutine Voronoi2Gen_Init

subroutine Voronoi2DiagramGen(pts, init3PtIds)
  type(Vector3d), intent(in) :: pts(:)
  integer, intent(in) :: init3PtIds(3)

  integer :: siteId
  integer, allocatable :: brokenVxIdList(:)
  logical :: bVxFlag(vorVxNum)
  type(Vector2d) :: pts_(size(pts))

  write(*,*) "= generate voronoi diagram.."
  write(*,*) "  site=", siteNum

  write(*,*) "* prepair.."

  do siteId=1, siteNum
     pts_(siteId) = pts(siteId)%v_(1:2)
  end do
  call VoronoiGen_prepair( pts_, init3PtIds )  
  isAddedSite(init3ptIds(:)) = .true.
  call print_graph()
stop

  !
  write(*,*) "* create voronoi mesh using increment method.."

  do siteId=1, siteNum
    if( mod(siteId, siteNum/5) == 0) then
      write(*,*) "..", siteId*100/siteNum, "%"
    end if

    if( .not. isAddedSite(siteId) ) then
!        write(*,'(a,i4)') "----", siteId
        isAddedSite(siteId) = .true.

        ! Step1, 2: collect an information with the broken voronoi vertecies by adding new site.
        call getBrokenVorVxIdList(siteId, pts_, brokenVxIdList, bVxFlag)
!        write(*,*) "broken Vx:", brokenVxIdList(:)

        ! Step3, 4: generate new voronoi region corresponding to new site
        !           using an information of broken voronoi vertecies.

        call construct_newVoronoiRegion(siteId, brokenVxIdList, bVxFlag, pts_)

     end if
  end do


end subroutine Voronoi2DiagramGen

subroutine Voronoi2Gen_Final()

  integer :: siteId

  if(allocated(vrVxRadius)) deallocate(vrVxRadius)
  if(allocated(vrVxvrVxG)) deallocate(vrVxvrVxG)
  if(allocated(vrVxvrRCG)) deallocate(vrVxvrRCG)
  if(allocated(vrVxPos)) deallocate(vrVxPos)
  if(allocated(isAddedSite)) deallocate(isAddedSite)
  
  if(allocated(vrRegionList)) then
     do siteId=1, size(vrRegionList)
        if(associated(vrRegionList(siteId)%vertIds)) deallocate(vrRegionList(siteId)%vertIds)
     end do
     deallocate(vrRegionList)
  end if
  
end subroutine Voronoi2Gen_Final

subroutine GetVrRegionPoints(siteId, vrVxs)
  integer, intent(in) :: siteId
  type(Vector2d), allocatable :: vrVxs(:)

  if(allocated(vrVxs)) deallocate(vrVxs)

  allocate( vrVxs(size(vrRegionList(siteId)%vertIds)) )
  vrVxs(:) = vrVxPos(vrRegionList(siteId)%vertIds)

end subroutine GetVrRegionPoints


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

subroutine VoronoiGen_prepair(pts, init3PtIds)
  
  type(Vector2d), intent(in) :: pts(:)
  integer, intent(in) :: init3PtIds(3)

  ! Work variables
  !
  integer :: vxId, i, siteId
  integer :: neighVRIds(3) ! The index of three voronoi regions which are a neighbor of a voronoi vertex.  
  real(DP) :: dist(3), dist_VorVx2unUsedSite
  type(vector2d) :: verticalPt, zeroVec

  ! Executable statements

  !
  !
  !

  vrVxRadius(:) = 0d0
  zeroVec = (/ 0d0, 0d0  /)
  vrVxPos(:) = zeroVec
  isAddedSite(:) = .false.

  vrVxPos(1) = 10d0*(/ 1d0, 0d0 /)
  vrVxPos(2) = 10d0*(/ -0.5d0,  0.5d0*sqrt(3d0)  /)
  vrVxPos(3) = 10d0*(/ -0.5d0, -0.5d0*sqrt(3d0)  /)
  vrVxPos(4) = getCircumCircCenter(pts(init3PtIds))

  do i=1, 3
     verticalPt = getVerticalPt( pts(init3PtIds(i)), pts(init3PtIds(mod(i,3)+1)), vrVxPos(4))
     verticalPt = vrVxPos(4) + 100d0*(verticalPt - vrVxPos(4))
write(*,*), i, ":", verticalPt%v_
     do vxId=1,3
        if( isLineSegsIntersect(vrVxPos(vxId), vrVxPos(mod(vxId,3)+1), vrVxPos(4), verticalPt) ) then
           vrVxPos(4+i) = getIntersectPt_lineSegs(vrVxPos(vxId), vrVxPos(mod(vxId,3)+1), vrVxPos(4), verticalPt)
           exit
        end if
     end do

  end do

!!$  ! Define the mapping array to convert the index of a voronoi vertex
!!$  ! into idecies of three voronoi regions. 
!!$
!!$  ! Initialize the mapping array to convert the index of a voronoi vertex
!!$  ! into the index of three vornoi vertecies which is a neighbor of it. 
!!$
!!$  vrVxvrVxG(:,1) = (/ 2,3,4 /)
!!$  vrVxvrVxG(:,2) = (/ 1,3,4 /)
!!$  vrVxvrVxG(:,3) = (/ 1,2,4 /)
!!$  vrVxvrVxG(:,4) = (/ 1,2,3 /)
!!$
!!$  vrVxvrRCG(:,1) = siteIds( vrVxvrVxG(:,1) )
!!$  vrVxvrRCG(:,2) = siteIds( vrVxvrVxG(:,2) )
!!$  vrVxvrRCG(:,3) = siteIds( vrVxvrVxG(:,3) )
!!$  vrVxvrRCG(:,4) = siteIds( vrVxvrVxG(:,4) )
!!$
!!$
!!$  ! Calculate the coordinates of four voronoi vetecies.
!!$  do vxId=1, 4
!!$     neighVRIds(:) = vrVxvrRCG(:, vxId)
!!$
!!$     vrVxPos(vxId) = calcCircumCircCenter( pts(neighVRIds(:)) ) 
!!$
!!$     ! Check if vorVx2VorRcId is defined correctly.
!!$     ! If the definition of id mapping is not correct, 
!!$     ! the voronoi vertecies will be recomputed after the correction of index. 
!!$     dist_VorVx2unUsedSite = geodesicArcLength( pts(siteIds(vxId)), vrVxPos(vxId) )
!!$     do i=1,3
!!$        if( geodesicArcLength(pts(neighVrIds(i)), vrVxPos(vxId)) > dist_VorVx2unUsedSite ) then
!!$           call swap(neighVrIds(2), neighVrIds(3))
!!$           call swap(vrVxvrVxG(2,vxId), vrVxvrVxG(3,vxId))
!!$           vrVxPos(vxId) = calcCircumCircCenter( pts(neighVRIds(:)) ) 
!!$           vrVxvrRCG(:,vxId) = neighVRIds(:)
!!$           exit     
!!$        end if
!!$     end do
!!$
!!$     vrVxRadius(vxId) = geodesicArcLength( pts(neighVRIds(1)), vrVxPos(vxId) )
!!$  end do
  
  currentVrVxNum = 7
  do i=1,4
     call complete_VrRCVrVxGTree(init3PtIds(i), mod(i,4)+1)
  end do

end subroutine VoronoiGen_prepair

subroutine getBrokenVorVxIdList(newSiteId, pts, brokenVxIdList, bVxFlag)
  integer, intent(in) :: newSiteId
  type(Vector2d), intent(in) :: pts(:)
  integer, intent(inout), allocatable :: brokenVxIdList(:)
  logical, intent(inout) :: bVxFlag(:)

  integer :: vrVxIdStack(currentVrVxNum)
  integer :: stackPtr, searchedPtr, vrVxId, childvrVxId, i, newVrVxId
  type(Vector2d) :: newSite
  integer :: lblVrVx(vorVxNum) ! [State] 1: undetermined, 2:out, 4:in 
  integer :: lblVrRC(siteNum) ! [state] 1: incident, 2:nonincident

  bVxFlag(:) = .false.
  lblVrVx(:) = 1
  lblVrRC(:) = 2

  newSite = pts(newSiteId)
  vrVxIdStack(1) = searchNeighVorVxId(newSiteId, pts)
  lblVrVx(vrVxIdStack(1)) = 4                ! labeled "in"
  lblVrRC( vrVxvrRCG(:,vrVxIdStack(1)) ) = 1 ! labeled "incident"
  bVxFlag(vrVxIdStack(1)) = .true.
  stackPtr = 1; searchedPtr = 0;
  

  do while(stackPtr /= searchedPtr)
     searchedPtr = searchedPtr + 1; vrVxId = vrVxIdStack(searchedPtr);
     
     do i=1,3
        childVrVxId = vrVxvrVxG(i, vrVxId)
        
        if( (lblVrVx(childvrVxId) == 1)  & ! check whether the label with vrVx is undetermined.
             & .and. getDistance_2Pt(newSite, vrVxPos(childvrVxId)) - vrVxRadius(childvrVxId) < 0 ) then
           
!!$           if( sum( lblVrVx(vrVxVrVxG(1:3,childvrVxId)) ) >= 8 ) then
!!$              lblVrVx(childvrVxId) = 2 ! labeled "out"
!!$           else
              stackPtr = stackPtr + 1; vrVxIdStack(stackPtr) = childvrVxId;
              lblVrVx(childVrVxId) = 4 !labeled "in"  
              bVxFlag(childvrVxId) = .true.
!!$           end if
 
        end if
     end do
  end do

  if(allocated(brokenVxIdList)) deallocate(brokenVxIdList)

  allocate(brokenVxIdList(stackPtr))
  brokenVxIdList(:) = vrVxIdStack(1:stackPtr)

contains
function isContained(ary, val) result(loc)
  integer, intent(in) :: ary(:), val
  integer :: loc

  integer :: arySize, i

  arySize = size(ary)
  loc = -1

  do i=1, arySize
     if(ary(i)==val) then
        loc = i; return
     end if
  end do
end function isContained

end subroutine getBrokenVorVxIdList


subroutine construct_newVoronoiRegion( newSiteId, bVxIdList, bVxFlag, pts )
  integer, intent(in) :: newSiteId
  integer, intent(in) :: bvxIdList(:)
  logical, intent(in) :: bVxFlag(:)
  type(Vector2d), intent(in) :: pts(:)

  integer :: i, j, k, bVxId
  integer :: newVrVxId, newVrVxIds(3*size(bVxIdList)), newVrVxNum
  integer :: tmpVrVxVrVxG(3,3*size(bvxIdList))
  integer :: tmpVrVxVrRCG(3,3*size(bvxIdList))
  integer :: neighVrVxGCorrectedIdList(3*size(bvxIdList))
  integer :: cycIds(3), neighVxId
  integer :: newVrVxIdLink(siteNum)
  integer :: endNewVxId, nextNewVxId, prevNewVxId

  newVrVxNum = 0
  newVrVxIdLink(:) = -1

  do i=1, size(bVxIdList)
     bVxId = bvxIdList(i)

     cycIds(:) = (/ 1, 2, 3 /)

     do j=1, 3
        neighVxId = vrVxvrVxG(j,bVxId)
        if( .not. bVxFlag(neighVxId) ) then
           newVrVxNum = newVrVxNum + 1
           if( newVrVxNum > size(bVxIdList)) then
              currentVrVxNum = currentVrVxNum + 1
              newVrVxId = currentVrVxNum
           else
              newVrVxId = bVxIdList(newVrVxNum)
           end if
           
           newVrVxIds(newVrVxNum) = newVrVxId

           tmpvrVxvrRCG(:,newVrVxNum) = &
                & (/ newSiteId, vrVxvrRCG(cycIds(2), bVxId), vrVxvrRCG(cycIds(3), bVxId) /)
           tmpVrVxVrVxG(1,newVrVxNum) = neighVxId
 
           do k=1,3
              if(bVxId==vrVxvrVxG(k,neighVxId)) neighVrVxGCorrectedIdList(newVrVxNum) = k
           end do

           newVrVxIdLink( vrVxvrRCG(cycIds(2),bVxId) ) = newVrVxId
           vrVxPos(newVrVxId) = getCircumCircCenter( pts(tmpVrVxVrRCG(:, newVrVxNum)) )
           vrVxRadius(newVrVxId) = getDistance_2Pt(pts(newSiteId), vrVxPos(newVrVxId))

        end if

        cycIds = cshift(cycIds, 1)
     end do
  end do

  do i=1, newVrVxNum
     neighVxId = tmpVrVxVrVxG(1,i)
     vrVxvrVxG(neighVrVxGCorrectedIdList(i), neighVxId) = newVrVxIds(i)
  end do

  vrVxvrRCG(:,newVrVxIds) = tmpVrVxVrRCG(:, 1:newVrVxNum)
  vrVxvrVxG(1,newVrVxIds) = tmpVrVxVrVxG(1, 1:newVrVxNum)


  !
  !write(*,*) "link:", newVorVxIdLink(:)
  endNewVxId = newVrVxIds(newVrVxNum)
  nextNewVxId = newVrVxIds(newVrVxNum)

  do while(.true.)

     prevNewVxId = nextNewVxId
     nextNewVxId = newVrVxIdLink(vrVxvrRCG(3,prevNewVxId))

!write(*,*) prevNewVxId, "-.>", nextNewVxId
     if(nextNewVxId == -1) then
        write(*,*) "error"; stop
     end if
     vrVxvrVxG(3, nextNewVxId) = prevNewVxId
     vrVxvrVxG(2, prevNewVxId) = nextNewVxId

     if ( nextNewVxId == endNewVxId ) exit
  end do

  call complete_VrRCVrVxGTree(newSiteId, newVrVxIds(1))
  do i=1, newVrVxNum
     call complete_VrRCVrVxGTree(vrVxVrRCG(2,newVrVxIds(i)), newVrVxIds(i))
  end do

!  call print_graph()

end subroutine construct_newVoronoiRegion

subroutine Voronoi2_setTopology(mesh)
  use PolyMesh_mod, only: &
       & PolyMesh, &
       & MAX_FACE_VERTEX_NUM, MAX_CELL_FACE_NUM

  type(PolyMesh), intent(inout) :: mesh
  
  integer :: vrVxId, siteId
  type(Face) :: tmpFace
  integer :: lvrVxNum, i, m, n
  integer :: faceNum
  type(Vector3d) :: vrVxPos_

  do vrVxId=1, vorVxNum
     vrVxPos_ = (/ vrVxPos(vrVxId)%v_(1), vrVxPos(vrVxId)%v_(2), 1d0 /)
     call PolyMesh_SetPoint(mesh, vrVxId, vrVxPos_)
  end do

  tmpFace%vertNum = 2
  faceNum = 0
  do siteId=1, siteNum

     lvrVxNum = size(vrRegionList(siteId)%vertIds(:))
     if(lvrVxNum > MAX_CELL_FACE_NUM) then
        write(*,*) "SiteId=", siteId, ", lvrVxNum=", lvrVxNum 
        call MessageNotify('E', module_name, "Occure an exception in setting the topology.")
        stop
     end if

     mesh%CellList(siteId)%faceNum = lvrVxNum

     do i=1, lvrVxNum
        vrVxId = vrRegionList(siteId)%vertIds(i)
        do m=1,3
           if(siteId == vrVxvrRCG(m,vrVxId)) then
              n = mod(m,3) + 1; 
              exit
           end if
        end do

        if(vrVxvrRCG(n,vrVxId) < siteId) then
!        write(*,*) "#reg v=", vId, "*tmp:", tmpVx2RCId

           tmpFace%vertIdList(1:2) = (/ vrVxVrVxG(mod(n,3)+1, vrVxId), vrVxId /)
           tmpFace%ownCellId = siteId
           tmpFace%neighCellId = vrVxvrRCG(n, vrVxId)

!write(*,*) "Face; own=", siteId, "neigh=", tmpVx2RCId(n)

           faceNum = faceNum + 1
           call PolyMesh_SetFace(mesh, faceNum, tmpFace)

           mesh%cellList(siteId)%faceIdList(i) = faceNum

           do m=1, size(vrRegionList(tmpFace%neighCellId)%vertIds)
              if( tmpFace%vertIdList(1) == vrRegionList(tmpFace%neighCellId)%vertIds(m) ) then
                 mesh%cellList(tmpFace%neighCellId)%faceIdList(m) = faceNum
                 exit
              end if

              if( m == size(vrRegionList(tmpFace%neighCellId)%vertIds) ) then
                 write(*,*) "error: The correspoinding vertex of neighbor cell can not be found!"
                 write(*,*) "edgeVertex=", tmpFace%vertIdList(1), vrVxPos(tmpFace%vertIdList(1))%v_
                 write(*,*) "neighCell=", tmpFace%neighCellId

                 stop
              end if
           end do

        end if

     end do ! each vertex
  end do ! each cell


!!$
!!$  write(*,*) "cell info--"
!!$  do m=1, siteNum
!!$    write(*,*) m, ":", mesh%cellList(m)%faceIdList(:), ":", mesh%cellList(m)%faceNum
!!$  end do

end subroutine Voronoi2_setTopology


!
!
function searchNeighVorVxId(newSiteId, pts) result(vrVxId)
  integer, intent(in) :: newSiteId 
  type(Vector2d), intent(in) :: pts(:)
  integer :: vrVxId

  real(DP), allocatable :: vs_distList(:)
  type(Vector2d) :: newSitePos
  integer :: i, neighSiteId(1), neighSiteId_(1), minLocId(1)
  integer :: lvrVxNum, nextId, startSiteId

  newSitePos = pts(newSiteId)
  startSiteId = newSiteId - 1
  if(newSiteId == 1) startSiteId = vrVxVrRCG(1,1)

  neighSiteId(1) = search_VrRegionContainedPt(newSitePos, pts, startSiteId)

  lvrVxNum = size(vrRegionList(neighSiteId(1))%vertIds)
  allocate(vs_distList(lvrVxNum))

  do i=1, lvrVxNum
     vrVxId = vrRegionList(neighSiteId(1))%vertIds(i)
     vs_distList(i) = getDistance_2Pt(newSitePos, vrVxPos(vrVxId)) - vrVxRadius(vrVxId)  
  end do


  minLocId = minLoc(vs_distList)
  vrVxId = vrRegionList(neighSiteId(1))%vertIds(minLocId(1))

end function searchNeighVorVxId


function search_VrRegionContainedPt(newSitePos, pts, startSiteId) result(neighSiteId)
  type(vector2d), intent(in) :: newSitePos
  type(vector2d), intent(in) :: pts(:)
  integer, intent(in) :: startSiteId
  integer :: neighSiteId

  logical :: checkedFlag(siteNum)
  integer :: currentSiteId

  checkedFlag = .false.
  currentSiteId = startSiteId
  do while(.true.)
     neighSiteId = moveNearVrRegion(currentSiteId)
     if(neighSiteId == currentSiteId .or. checkedFlag(neighSiteId) ) exit

     currentSiteId = neighSiteId
  end do

contains
function moveNearVrRegion(siteId) result(nextSiteId)
  integer, intent(in) :: siteId
  integer :: nextSiteId

  integer :: vxId, i, j, vxNum
  real(DP) :: dist(1+size(vrRegionList(siteId)%vertIds))
  integer :: RCList(1+size(vrRegionList(siteId)%vertIds))
  integer :: minid(1)

  checkedFlag(siteId) = .true.
 ! write(*,*)  "dist=", geodesicArcLength(pts(newSiteId), pts(siteId)), newSiteId, siteId
  vxNum = size(vrRegionList(siteId)%vertIds)

  do i=1, vxNum
     vxId = vrRegionList(siteId)%vertIds(i)
     do j=1, 3
        if( siteId == vrVxvrRCG(j,vxId) ) exit
     end do
     RCList(i) = vrVxvrRCG(mod(j,3)+1, vxId)
     dist(i) = getDistance_2Pt(newSitePos, pts(RCList(i)))
  end do

  RCList(vxNum+1) = siteId
  dist(vxNum+1) = getDistance_2Pt(newSitePos, pts(siteId))
  
  minid = minLoc(dist)
  nextSiteId = RCList(minId(1))

end function moveNearVrRegion

end function search_VrRegionContainedPt


subroutine complete_VrRCVrVxGTree(siteId, startVrVxId)
  integer, intent(in) :: siteId
  integer, intent(in) :: startVrVxId

  integer :: currentVrVxId, lvrVxId, i
  integer :: tmplVrVxList(vorVxNum)
  integer :: lvrVxNum


  currentVrVxId = startVrVxId
  lvrVxNum = 0
  do while(.true.)
     lvrVxNum = lvrVxNum + 1
     tmplVrVxList(lvrVxNum) = currentVrVxId

     do i=1,3
        if( siteId == vrVxvrRCG(i,currentVrVxId) ) exit;
     end do

     currentVrVxId = vrVxvrVxG(mod(i,3)+1, currentVrVxId)
     if(currentVrVxId==startVrVxId) exit;
     if(lvrVxNum > vorVxNum ) then
        write(*,*) "Fail completing information of voronoi vertecies. siteId=", siteId
        stop
     end if
  end do

  if(associated(vrRegionList(siteId)%vertIds)) deallocate(vrRegionList(siteId)%vertIds)

  allocate(vrRegionList(siteId)%vertIds(lvrVxNum))
  vrRegionList(siteId)%vertIds(:) = tmplVrVxList(1:lvrVxNum)

end subroutine complete_VrRCVrVxGTree


!
!
!
subroutine print_graph()

  integer :: vxId, siteId

  write(*,*) "----- * vrVxId: vrVxvrVx Graph,  vrVxvrRC Graph"
  do vxId=1, currentVrVxNum
     write(*,'(i4,a,3i6,a,3i6, 2f15.9)') vxId, ":", vrVxvrVxG(1:3, vxId), ",", vrVxvrRcG(1:3, vxId)
  end do

  write(*,*) "----- * siteId: vrRCvrVx Graph"
  do siteId=1, siteNum
     if(isAddedSite(siteId)) write(*,'(i6,a,12i6)') siteId, ":", vrRegionList(siteId)%vertIds(:)  
  end do
  
end subroutine print_graph


function getDistance_2Pt(pt1, pt2) result(dist)
  type(Vector2d) :: pt1, pt2
  real(DP) :: dist

  dist = l2norm(pt1 - pt2)

end function getDistance_2Pt

subroutine swap(i1, i2)
  integer, intent(inout) :: i1, i2
  integer :: tmp

  tmp = i1
  i1 = i2
  i2 = tmp
end subroutine swap

end module VoronoiGen2_mod
