using Calculation;

int main (string[] args)
{
	stdout.printf("avaible operators:`+`, `-`, `*`, `/`, `^`, `%`, `E`, `!`\navaible constants:`p`/`pi`, `e`\navaible functions:`sqrt`,`root`(x,y), `mod`, `sin`, `cos`, `tan`, `sinh`,`cosh`,`tanh`\nMode:degrees\n\n");


	string input;
	var running=true;

	var test=new Calculation.Evaluation(config(){custom_variable=Replaceable(){key={"x","i"},value={2,1}}});
	while(running)
	{
	    input=stdin.read_line();

	    if(input=="exit")
	        running=false;
	    else if(input.length>0) {
	    int64 msec = GLib.get_real_time();
            try{
            double r=test.eval_auto(input);
	        stdout.printf(@"result:$r\ntime:$( (GLib.get_real_time()-msec)/1000 )\n\n");
	        }
	        catch (Error e) {
	            stdout.printf(e.message+"\n\n");
	        }
	    }
	}
    stdout.printf("Calculator stopped\n");
	return 0;
}

