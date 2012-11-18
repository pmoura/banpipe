:- protocol(file_indexp).

	:- info([
		version is 1.0,
		author is 'Christian Theil Have',
		date is 2012/11/06,
		comment is 'Protocol for result file index. A task-call (Module,Task,InputFiles,Options) serves as unique key to identify a set of result files.' ]).
	
	:- public(result_files_allocate/5).
	:- info(result_files_allocate/5,
		[ comment is 'Generates and reserves a list of filenames (Filenames) for given task-call. If the task-call succeeds and generates the files, result_files_commit/4 should be called',
		  argnames is [ 'Module', 'Task', 'InputFiles', 'Options', 'Filenames' ]]).
	
	:- public(result_files_commit/4).
	:- info(result_files_commit/4,
		[ comment is 'Finalizes transaction: Reserved filenames are marked as available. Only after result_files_commit have been called will the corresponding files be return by result_files/5',
		  argnames is [ 'Module', 'Task', 'InputFiles', 'Options' ]]).
	
	:- public(result_files_rollback/4).
	:- info(result_files_rollback/4,
		[ comment is 'Remove filename allocations from database.',
		  argnames is [ 'Module', 'Task', 'InputFiles', 'Options' ]]).
	
	:- public(result_files/5).
	:- info(result_files/5,
		[ comment is 'Retrieve the Filenames matching (Module,Task,Options,InputFiles) from the file index.',
		  argnames is ['Module','Task','InputFiles','Options','Filenames']]).
		
	:- public(result_files_allocate_time/5).
	:- info(result_files_allocate_time/5,
		[ comment is 'The time at which result files identified by (Module,Task,InputFiles,Options) was allocated. AllocateTime is on the form time(Year,Mon,Day,Hour,Min,Sec).',
		  argnames is ['Module','Task','InputFiles','Options','AllocateTime']]).
		
	:- public(result_files_commit_time/5).
	:- info(result_files_commit_time/5,
		[ comment is 'The time at which result files identified by (Module,Task,InputFiles,Options) as committed (created). CommitTime is on the form time(Year,Mon,Day,Hour,Min,Sec).',
		  argnames is ['Module','Task','InputFiles','Options','CommitTime']]).
:- end_protocol.

:- object(term_file_index(_IndexFile), implements(file_indexp)).
	:- info([
		version is 1.0,
		author is 'Christian Theil Have',
		date is 2012/11/06,
		comment is 'The file_index is used to keep track of files generated by running tasks in modules. It is primarily used internally, and is not expected te be used directly from banpipe modules/tasks. In fact, updating the index from a model (which runs a separate process), may damage the index due to concurrency issues'
	]).
	
	% This file index represents the file index using terms on the form
	% files(Index,AllocatedTimestamp,CommitTimestamp,ResultFiles,Module,Task,InputFiles,Options)
	% Index: is an atom representing an integer
	% AllocatedTimestamp: a timestamp (time(Year,Mon,Day,Hour,Min,Sec) representing the time the result files were allocated
	% CommitTimestamp: a timestamp (time(Year,Mon,Day,Hour,Min,Sec) representing the time the result files were committed
	% ResultFiles: A list of (fully qualified) result files
	% Module: fully qualified module name
	% Task: task name
	% InputFiles: Fully qualified list of input files
	% Options: List of option terms on the form key(value)
	
	:- private(get_index_file/1).
	get_index_file(IndexFile) :-
		parameter(1,Param1),
		IndexFile = prolog_file(Param1),
		(IndexFile::exists -> true ; IndexFile::touch).
	
	consistency_check. % FIXME: do somethinh useful
	
	result_files_allocate(Module,Task,InputFiles,Options,ResultFiles) :-
		get_index_file(IndexFile),
 		current_timestamp(AllocatedTimestamp),
 		IndexFile::dirname(IndexDir),
		IndexFile::read_terms(Terms),
 		next_available_index(Terms, Index),
 		term_extras::term_to_atom(Index,IndexAtom),
 		findall(Filename, (
			list::nth1(FileNo,ResultFiles,Filename),
			term_extras::term_to_atom(FileNo,FileNoAtom),
			meta::foldl(atom_concat,'',[IndexDir, Module, '_',Task,'_',IndexAtom,'_', FileNoAtom, '.gen'], Filename)
		),ResultFiles),
		IndexFile::append([files(IndexAtom,AllocatedTimestamp,null,ResultFiles,Module,Task,InputFiles,Options)]).

	result_files_commit(Module,Task,InputFiles,Options) :-
		get_index_file(IndexFile),
		IndexFile::select(files(Id,AllocatedTimestamp,null,ResultFiles,Module,Task,InputFiles,Options),RestEntries),
		current_timestamp(CommitTimestamp),
		IndexFile::write_terms([files(Id,AllocatedTimestamp,CommitTimestamp,ResultFiles,Module,Task,InputFiles,Options)|RestEntries]).

	result_files_rollback(Module,Task,InputFiles,Options) :-
		get_index_file(IndexFile),
		IndexFile::select(files(_,_,null,_,Module,Task,InputFiles,Options),RestEntries),
		IndexFile::write_terms(RestEntries).
		
	result_files(Module,Task,InputFiles,Options,ResultFiles) :-
		get_index_file(IndexFile),
		IndexFile::member(files(_,_,time(_,_,_,_,_,_),ResultFiles,Module,Task,InputFiles,Options)).

	result_files_allocate_time(Module,Task,InputFiles,Options,AllocTs) :-
		get_index_file(IndexFile),
		IndexFile::member(files(_,AllocTs,_,_ResultFiles,Module,Task,InputFiles,Options)).
	
	result_files_commit_time(Module,Task,InputFiles,Options,time(Year,Day,Mon,Hour,Min,Sec)) :-
		get_index_file(IndexFile),
		IndexFile::member(files(_,_AllocTs,time(Year,Day,Mon,Hour,Min,Sec),_ResultFiles,Module,Task,InputFiles,Options)).
		
	:- private(next_available_index/2).
	:- info(next_available_index/2, [
		comment is 'Given Terms, unify NextAvailableIndex with a unique index not occuring as index in terms.',
		argnames is ['Terms','NextAvailableIndex']]).
	next_available_index(Terms, NextAvailableIndex) :-
			largest_index(Terms,LargestIndex),
			NextAvailableIndex is LargestIndex + 1.
			
	:- private(largest_index/2).
	:- info(largest_index/2, [ 
		comment is 'True if LargestIndex is the largest index occuring in Terms',
		argnames is ['Terms','LargestIndex']]).
	largest_index([], 0).
	largest_index([Term|Rest], LargestIndex) :-
		Term =.. [ files, TermIndexAtom | _ ],
		term_extras::atom_integer(TermIndexAtom,Index),
		largest_index(Rest,MaxRestIndex),
		max(Index,MaxRestIndex,LargestIndex).
		
	max(A,B,A) :- A > B.
	max(_A,B,B).

	:- private(current_timestamp/1).
	:- info(current_timestamp/1,[
		comment is 'Get a timestamp corresponding to the current time', 
		argnames is ['time(Year,Mon,Day,Hour,Min,Sec)']]).
	current_timestamp(time(Year,Mon,Day,Hour,Min,Sec)) :-
		date::today(Year,Mon,Day),
		time::now(Hour,Min,Sec).
:- end_object.