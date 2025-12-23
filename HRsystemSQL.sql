create database HRsystem;
use HRsystem;

create table department (
    deptId int identity primary key,
    deptName varchar(50) unique not null,
    deptStatus varchar(10) check (deptStatus in ('active','inactive')) not null
);

create table designation (
    designationId int identity primary key,
    designationName varchar(50) not null,
    designationStatus varchar(10) check (designationStatus in ('active','inactive')) not null,
    deptId int null,
    foreign key (deptId) references department(deptId)
);

create table role (
    roleId int identity primary key,
    roleName varchar(20) unique not null, -- admin, manager, employee
    roleStatus varchar(10) check (roleStatus in ('active','inactive')) not null
);

create table employee (
    empId int identity primary key,
    empName varchar(100) not null,
    empStatus varchar(10) check (empStatus in ('active','inactive')) not null,
    contact varchar(15),
    dateOfJoining date,
    dateOfBirth date,

    roleId int not null,

    deptId int null,

    designationId int null,

    managerId int null,

    foreign key (roleId) references role(roleId),
    foreign key (deptId) references department(deptId),
    foreign key (designationId) references designation(designationId),
    foreign key (managerId) references employee(empId)
);

create table eventType (
    eventTypeId int identity primary key,
    eventTypeName varchar(50),
    eventTypeStatus varchar(10) check (eventTypeStatus in ('active','inactive')),
    eventColor varchar(20)
);

create table event (
    eventId int identity primary key,
    eventName varchar(100),
    eventDate date,
    eventStatus varchar(10) check (eventStatus in ('active','inactive')),
    eventTypeId int,
    foreign key (eventTypeId) references eventType(eventTypeId)
);

create table leaveType (
    leaveTypeId int identity primary key,
    leaveTypeName varchar(50),
    leaveTypeStatus varchar(10) check (leaveTypeStatus in ('active','inactive'))
);

create table leaveAllocation (
    leaveAllocationId int identity primary key,
    deptId int,
    leaveTypeId int,
    noOfDays int,
    foreign key (deptId) references department(deptId),
    foreign key (leaveTypeId) references leaveType(leaveTypeId)
);

create table leaveRequest (
    leaveRequestId int identity primary key,
    empId int,
    leaveTypeId int,
    fromDate date,
    toDate date,
    reason varchar(200),
    requestedDays int,
    requestStatus varchar(10) check (requestStatus in ('approved','rejected')),
    foreign key (empId) references employee(empId),
    foreign key (leaveTypeId) references leaveType(leaveTypeId)
);


CREATE TRIGGER trg_DefaultEmpStatus
ON employee
AFTER INSERT
AS
BEGIN
    UPDATE e
    SET empStatus = 'active'
    FROM employee e
    JOIN inserted i ON e.empId = i.empId
    WHERE i.empStatus IS NULL;
END;


CREATE TRIGGER trg_PreventDeptDelete
ON department
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM employee e
        JOIN deleted d ON e.deptId = d.deptId
    )
    BEGIN
        RAISERROR ('Cannot delete department with active employees', 16, 1);
    END
    ELSE
    BEGIN
        DELETE FROM department
        WHERE deptId IN (SELECT deptId FROM deleted);
    END
END;

CREATE TRIGGER trg_ValidateLeaveDates
ON leaveRequest
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE fromDate > toDate
    )
    BEGIN
        RAISERROR ('From date cannot be greater than To date', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;

CREATE TRIGGER trg_CheckLeaveBalance
ON leaveRequest
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted lr
        JOIN employee e ON lr.empId = e.empId
        JOIN leaveAllocation la 
            ON la.deptId = e.deptId 
           AND la.leaveTypeId = lr.leaveTypeId
        WHERE lr.requestedDays > la.noOfDays
    )
    BEGIN
        RAISERROR ('Requested leave days exceed allocated limit', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;



-- dept procedures
--select
create proc sp_getDepartments
as
begin
    select * from department;
end;
--insert
create proc sp_insertDepartment
@deptName varchar(50),
@deptStatus varchar(10)
as
begin
    insert into department(deptName, deptStatus)
    values (@deptName, @deptStatus);
end;
--update
create proc sp_updateDepartment
@deptId int,
@deptName varchar(50),
@deptStatus varchar(10)
as
begin
    update department
    set deptName=@deptName, deptStatus=@deptStatus
    where deptId=@deptId;
end;
--delete
create proc sp_deleteDepartment
@deptId int
as
begin
    delete from department where deptId=@deptId;
end;

--designation procedures
--select
create proc sp_getDesignations
as
begin
    select * from designation;
end;
--insert
create proc sp_insertDesignation
@designationName varchar(50),
@designationStatus varchar(10),
@deptId int = null
as
begin
    insert into designation
    values (@designationName,@designationStatus,@deptId);
end;
--update
create proc sp_updateDesignation
@designationId int,
@designationName varchar(50),
@designationStatus varchar(10),
@deptId int = null
as
begin
    update designation
    set designationName=@designationName,
        designationStatus=@designationStatus,
        deptId=@deptId
    where designationId=@designationId;
end;
--delete
create proc sp_deleteDesignation
@designationId int
as
begin
    delete from designation where designationId=@designationId;
end;

-- role procedures
--select
create proc sp_getRoles
as
begin
    select * from role;
end;
--insert
create proc sp_insertRole
@roleName varchar(20),
@roleStatus varchar(10)
as
begin
    insert into role(roleName,roleStatus)
    values (@roleName,@roleStatus);
end;
--update
create proc sp_updateRole
@roleId int,
@roleStatus varchar(10)
as
begin
    update role set roleStatus=@roleStatus where roleId=@roleId;
end;
--delete
create proc sp_deleteRole
@roleId int
as
begin
    delete from role where roleId=@roleId;
end;

-- emp procedures
--select
create proc sp_getEmployees
as
begin
    select 
        e.empId,
        e.empName,
        r.roleName,
        d.deptName,
        g.designationName,
        m.empName as managerName
    from employee e
    join role r on e.roleId=r.roleId
    left join department d on e.deptId=d.deptId
    left join designation g on e.designationId=g.designationId
    left join employee m on e.managerId=m.empId;
end;
--insert
create proc sp_insertEmployee
@empName varchar(100),
@empStatus varchar(10),
@roleId int,
@deptId int = null,
@designationId int = null,
@managerId int = null
as
begin
    insert into employee
    values (@empName,@empStatus,null,null,null,
            @roleId,@deptId,@designationId,@managerId);
end;
--update
create proc sp_updateEmployee
@empId int,
@empStatus varchar(10)
as
begin
    update employee set empStatus=@empStatus where empId=@empId;
end;
--delete
create proc sp_deleteEmployee
@empId int
as
begin
    delete from employee where empId=@empId;
end;

-- eventType procedures
--select
create proc sp_getEventTypes as select * from eventType;
--insert
create proc sp_insertEventType
@name varchar(50), @status varchar(10), @color varchar(20)
as insert into eventType values (@name,@status,@color);
--update
create proc sp_updateEventType
@id int, @status varchar(10)
as update eventType set eventTypeStatus=@status where eventTypeId=@id;
--delete
create proc sp_deleteEventType
@id int
as delete from eventType where eventTypeId=@id;

-- event procedures
--select
create proc sp_getEvents as select * from event;
--insert
create proc sp_insertEvent
@name varchar(100), @date date, @status varchar(10), @typeId int
as insert into event values (@name,@date,@status,@typeId);
--update
create proc sp_updateEvent
@id int, @status varchar(10)
as update event set eventStatus=@status where eventId=@id;
--delete
create proc sp_deleteEvent
@id int
as delete from event where eventId=@id;

-- leavetype procedures
--select
create proc sp_getLeaveTypes as select * from leaveType;
--insert
create proc sp_insertLeaveType
@name varchar(50), @status varchar(10)
as insert into leaveType values (@name,@status);
--update
create proc sp_updateLeaveType
@id int, @status varchar(10)
as update leaveType set leaveTypeStatus=@status where leaveTypeId=@id;
--delete
create proc sp_deleteLeaveType
@id int
as delete from leaveType where leaveTypeId=@id;

-- leaveAllocation procedures
--select
create proc sp_getLeaveAllocations as select * from leaveAllocation;
--insert
create proc sp_insertLeaveAllocation
@deptId int, @leaveTypeId int, @days int
as insert into leaveAllocation values (@deptId,@leaveTypeId,@days);
--update
create proc sp_updateLeaveAllocation
@id int, @days int
as update leaveAllocation set noOfDays=@days where leaveAllocationId=@id;
--delete
create proc sp_deleteLeaveAllocation
@id int
as delete from leaveAllocation where leaveAllocationId=@id;

-- leaveRequest procedures
--select
create proc sp_getLeaveRequests as select * from leaveRequest;
--insert
create proc sp_insertLeaveRequest
@empId int, @leaveTypeId int, @from date, @to date,
@reason varchar(200), @days int
as
begin
    insert into leaveRequest
    values (@empId,@leaveTypeId,@from,@to,@reason,@days,'rejected');
end;
--update
create proc sp_updateLeaveRequestStatus
@id int, @status varchar(10)
as update leaveRequest set requestStatus=@status where leaveRequestId=@id;
--delete
create proc sp_deleteLeaveRequest
@id int
as delete from leaveRequest where leaveRequestId=@id;

exec sp_getDepartments;
exec sp_getDesignations;
exec sp_getRoles;
exec sp_getEmployees;
exec sp_getEventTypes;
exec sp_getEvents;
exec sp_getLeaveTypes;
exec sp_getLeaveAllocations;
exec sp_getLeaveRequests;
