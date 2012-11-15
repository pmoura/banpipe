:- protocol(invokerp).
	:- info([
		version is 1.0,
		author is 'Christian Theil Have',
		date is 2012/11/14,
		comment is 'Protocal that invokers must implement']).
		
	:- public(run/2).
	:- info(run/2, [ 
		comment is 'Run Goal within the file InterfaceFile',
		argnames is ['InterfaceFile','Goal']]).
		
:- end_protocol.
:- object(logger_invoker,implements(invokerp)).
	:- info([
		version is 1.0,
		author is 'Christian Theil Have',
		date is 2012/11/14,
		comment is 'Simple invoker which does nothing, but logs the invocation.']).
		
	run(InterfaceFile,Goal) :-
		write('(simulating) Running goal '),
		writeln(Goal),
		writeln(' in file '),
		writeln(InterfaceFile).
:- end_object.

:- object(bprolog_invoker,implements(invokerp)).
	:- info([
		version is 1.0,
		author is 'Christian Theil Have',
		date is 2012/11/14,
		comment is 'Invoker which launches a B-Prolog process and runs the goal within that process']).
	
	:- protected(key_invoke_command/1).
	key_invoke_command(invoke_command(bprolog)).

	run(InterfaceFile,Goal) :-
		shell::working_directory(CurrentDir),
		file(InterfaceFile)::dirname(ModuleDir),
		shell::change_directory(ModuleDir),
		::key_invoke_command(InvokeCmdKey),
		config::get(InvokeCmdKey,Exec),
		term_extras::term_to_atom(Goal,GoalAtom),
		meta::foldl(atom_concat,'',[Exec,' -g "assert(task(_)), consult(\'', InterfaceFile, '\'),', GoalAtom,',halt."'],Command),
		shell::exec(Command),
		shell::change_directory(CurrentDir).
:- end_object.



:- object(prism_invoker,extends(bprolog_invoker)).
	:- info([
		version is 1.0,
		author is 'Christian Theil Have',
		date is 2012/11/14,
		comment is 'Invoker which launches a PRISM process and runs the goal within that process']).
		
		key_invoke_command(invoke_command(prism)).
:- end_object.