using Calculation;

int main (string[] args)
{
	stdout.printf("avaible operators:`+`, `-`, `*`, `/`, `^`, `%`, `E`, `!`\navaible constants:`p`/`pi`, `e`\navaible functions:`sqrt`,`root`(x,y), `mod`, `sin`, `cos`, `tan`, `sinh`,`cosh`,`tanh`\nMode:degrees\n\n");


	string input;
	var running=true;

	while(running)
	{
	    input=stdin.read_line();

	    if(input=="exit")
	        running=false;
	    else if(input.length>0) {
	    int64 msec = GLib.get_real_time();
	    var test=new Calculation.Evaluation(config(){custom_variable=Replaceable(){key={"x","i"},value={2,1}}});
	        test.input=input;

	        try {
	            test.split();
	        }
	        catch (Error e) {
	            stdout.printf(e.message+"\n\n");
	            continue;
	        }
            try{
	            test.prepare();
	            }
	            catch(Error e) {
	                stdout.printf(e.message+"\n\n");
	                continue;
	            }
	        try{
                test.eval();
	            }
	            catch(Error e) {
	                stdout.printf(e.message+"\n\n");
	                continue;
	            }

	        stdout.printf(@"result:$(test.result)\ntime:$( (GLib.get_real_time()-msec)/1000 )\n\n");
	    }
	}
    stdout.printf("Calculator stopped\n");
	return 0;
}

