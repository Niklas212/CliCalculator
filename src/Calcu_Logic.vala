namespace Calculation {
using GLib.Math;

public errordomain CALC_ERROR {
    INVALID_SYMBOL,
    MISSING_ARGUMENT,
    REMAINING_ARGUMENT,
    MISSING_CLOSING_BRACKET,
    MISSING_OPENING_BRACKET,
    UNKNOWN
    }


public class Evaluation:GLib.Object
{


    public Evaluation(config c=config(){use_degrees=true})
    {
        this.update(c);
    }

    public void update(config c) {
        fun_intern=get_intern_functions(c.use_degrees);
        operator=get_operator();
        variable=get_custom_variable(c.custom_variable);
        con=c;
    }

    public config con;

	private PreparePart[] parts={};
	public string input{get; set; default="";}
	//public string multiple_numbers_start{get; set; default="{";}
	//public string multiple_numbers_end{get; set; default="}";}
	public double? result{get; private set; default=null;}
	//public string? s_result{get; private set; default=null;}
	private GenericArray<Part?> section=new GenericArray<Part?>();
	private GenericArray<Sequence?>sequence=new GenericArray<Sequence?>();

	public int bracket{get; set; default=5;}


	public Operation operator{get; set;}
    public Func fun_intern{get; set; }
	public string[] control{get; set; default={"(",")",","," "};}
	public Replaceable variable{get; set;}

    public void clear(){
        parts={};
        section.remove_range(0,section.length);
        sequence.remove_range(0,sequence.length);
    }

	public void split() throws CALC_ERROR
	{
        bool can_negative=true;
        bool check_mul=false;

		var num=PreparePart(){type=Type.NUMBER};
		var opr=PreparePart(){type=Type.OPERATOR};
		var cnt=PreparePart(){type=Type.CONTROL};
		var vrb=PreparePart(){type=Type.VARIABLE};
		var fui=PreparePart(){type=Type.EXPRESSION};
		PreparePart ap={};

		int len_num;

		int ind_op=-1;
		int ind_cnt=-1;
		int ind_vrb=-1;
		int ind_fui=-1;

		while(input.length>0) {

			num.value=next_number(input,out len_num, can_negative);
			opr.value=next_match(input,operator.key, out ind_op);
			cnt.value=next_match(input,control, out ind_cnt);
			vrb.value=next_match(input,variable.key, out ind_vrb);
			fui.value=next_match(input,fun_intern.key, out ind_fui);

			opr.length=opr.value.length;
			cnt.length=cnt.value.length;
			vrb.length=vrb.value.length;
			fui.length=fui.value.length;
			num.length=len_num;

			opr.index=ind_op;
			cnt.index=ind_cnt;
			vrb.index=ind_vrb;
            fui.index=ind_fui;

			ap=get_longest(opr,num,cnt,vrb,fui);

			if(ap.length>0)
			    {
                    if(check_mul&&(!(ap.type==Type.OPERATOR||ap.type==Type.NUMBER||(ap.type==Type.CONTROL&&!(ap.value=="(")))))
                        parts+=PreparePart(){value="*", type=Type.OPERATOR, length=1, index=2};
                    //stdout.printf("ja");
                   if (ap.value == "-" && (parts.length == 0 || (parts[parts.length - 1].type == Type.CONTROL && parts[parts.length - 1].value != ")")))
                        {parts += PreparePart(){value="0", type=Type.NUMBER};
                        stdout.printf("jaaa");
                        }

			        parts+=ap;
			        input=input[ap.length:input.length];

			        can_negative=(ap.type==Type.OPERATOR||(ap.type==Type.CONTROL&&ap.value!=")"));
			        check_mul=(ap.type==Type.NUMBER||ap.type==Type.VARIABLE||ap.value==")");
			    }
			else {
			    throw new CALC_ERROR.INVALID_SYMBOL (@"the symbol `$(input[0:1])` is not known");
			}

		}
	}

	public void prepare() throws CALC_ERROR
	{
		int bracket_value = 0;

		foreach(PreparePart part in parts)
		{

			switch(part.type)
			{
				case Type.VARIABLE: {
					section.add(Part(){
						value=variable.value[part.index]
					});

					break;
				}
				case Type.NUMBER: {
					section.add(Part() {
						value=double.parse(part.value)
					});

					break;
				}
				case Type.OPERATOR: {
					section.add(Part(){
						eval=operator.eval[part.index]
					});
					sequence.add(Sequence(){
						priority=bracket_value+operator.priority[part.index],
						arguments=operator.eval[part.index].arg_left+operator.eval[part.index].arg_right,
						index=section.length-1
					});

					break;
				}
				case Type.EXPRESSION: {
				    section.add(Part(){
				        eval=fun_intern.eval[part.index]
				    });
				    sequence.add(Sequence(){
				        priority=4+bracket_value,
				        arguments=fun_intern.eval[part.index].arg_right,
				        index=section.length-1
				    });

				    break;
				}
				case Type.CONTROL: {
					if(part.value==")") {
					    bracket_value-=bracket;
					}
					else if(part.value=="(") {
					    bracket_value+=bracket;
					}
					break;
				}
				default: {
					break;
				}
			}
		}

	if(bracket_value!=0) {
	    if(bracket_value>0) {
            throw new CALC_ERROR.MISSING_CLOSING_BRACKET(@" `$(bracket_value/bracket)` closing $((bracket_value/bracket==1)?"bracket is":"brackets are") missing");
	    }
	    else {
	        bracket_value*=-1;
            throw new CALC_ERROR.MISSING_OPENING_BRACKET(@" `$(bracket_value/bracket)` opening $((bracket_value/bracket==1)?"bracket is":"brackets are") missing");
	    }
	}

	}

	public void eval() throws CALC_ERROR
	{
//
//
//
	    int score=0;
	    int promised=0;
	    int changes=1;
	    bool control=false;
	    Part sec;

	    for (int i=0; i<section.length; i++) {
	    sec=section.get(i);
	        changes=1;
	        control=false;
            if(sec.value==null)
            {
                promised+=sec.eval.arg_right;
                changes=1-sec.eval.arg_left;
                control=true;
            }

                if(promised>0&&score!=0)
                    promised-=changes;
                else
                    score+=changes;
                if(control&&score!=1) {
                if(score<1)
                    throw new CALC_ERROR.MISSING_ARGUMENT("Missing Argument, a left argument is required");
                else
                    throw new CALC_ERROR.REMAINING_ARGUMENT("Remaining Argument");
                    }
	    }

        if(promised!=0)
            throw new CALC_ERROR.MISSING_ARGUMENT("Missing Argument");
        if(score!=1) {
                if(score<1)
                    throw new CALC_ERROR.MISSING_ARGUMENT("Missing Argument");
                else
                    throw new CALC_ERROR.REMAINING_ARGUMENT("Remaining Argument");
            }
//
//
//
		//sortierung nach priority
		sequence.sort(sorting);
		//index berechnung
		sequence=eval_seq(sequence);


		for(int i=0; i<sequence.length; i++)
		{
			var ind=sequence.get(i).index;
			var part=section.get(ind);

			double[]arg={};

			//get arg_left
			for(int l=0; l<part.eval.arg_left; l++)
			{
				arg+=section.get(ind-part.eval.arg_left).value;
				section.remove_index(ind-part.eval.arg_left);
			}

			//get arg_right
			for(int l=0; l<part.eval.arg_right; l++)
			{
				arg+=section.get(ind+1-part.eval.arg_left).value;
				section.remove_index(ind+1-part.eval.arg_left);
			}

			section.set(ind-part.eval.arg_left,Part(){
				value=part.eval.eval(arg)
			});
		}
		result=section.get(0).value??null;
		//s_result=result.to_string();
		if(con.round_decimal) {
		    result=round(result*pow(10,con.decimal_digit))/pow(10,con.decimal_digit);
		    //s_result=result.to_string();
	    }
	}

    public double eval_auto(string in, config? c=null) throws CALC_ERROR {
        this.input=in;
        if(c!=null)
            this.update(c);
        try{
            this.split();
            try{
                this.prepare();
                try{
                    this.eval();
                }
                catch(Error e) {
                    this.clear();
                    throw e;
                }
            }
            catch(Error e) {
                this.clear();
                throw e;
            }
        }
        catch(Error e) {
            this.clear();
            throw e;
        }
        this.clear();
        return this.result;
    }

	private PreparePart get_longest(PreparePart x,...)
	{
		var ret=x;
		va_list list = va_list ();

		for (PreparePart? y = list.arg<PreparePart?> (); y != null; y = list.arg<PreparePart?> ())
		{
			if(y.length>ret.length)
				ret=y;
		}

		return ret;
	}

	// zu genie <
	CompareFunc<Sequence?> sorting = (a, b) => {
		return (int) (a.priority < b.priority) - (int) (a.priority > b.priority);
	};
	// >
}

}
