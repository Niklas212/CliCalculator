
public class LinkedList <T> {

    public int length {get; private set;}
    private Node <T> ? start;
    private unowned Node <T> ? end;

    public delegate bool SortingFunction <T> (T a, T b);
    public delegate bool CompareFunction <T> (T a);
    public delegate void Each <T> (T value, ref bool proceed);
    public delegate void EachI <T> (T value, int index, ref bool proceed);
    public delegate void EachNode <T> (Node <T> value, ref bool proceed);
    public delegate void EachNodeI <T> (Node <T> node, int index, ref bool proceed);

	#if PROFILE_LINKED_LIST

	private struct Info {
		int64 times_called;
		int64 time;
		string name;

		Info (string name) {
			times_called = 0;
			time = 0;
			this.name = name;
		}

		public inline void start () {
			time -= GLib.get_real_time ();
		}

		public inline void end () {
			time += GLib.get_real_time ();
			times_called ++;
		}

		public string to_string () {
			return @"$name:\t$(times_called) times\t$(time) ns\tavg: $( (times_called != 0) ? time / times_called : -1) ns\n";
		}
	}

	private static Info append_info = Info ("append");
	private static Info insert_info = Info ("insert");
	private static Info insert_sorted_info = Info ("insert-sorted");
	private static Info remove_info = Info ("remove");
	private static Info remove_next_node_info = Info ("remove-next-node");
	private static Info get_info = Info ("get");
	private static Info set_info = Info ("set");

	public string to_string () {
		return @"$append_info$insert_sorted_info$remove_info$remove_next_node_info$set_info$get_info";
	}
	#endif

    public T first {
			get {
				return start.value;
			}

			set {
				if (length > 0) {
					start.value = value;
				} else {
					append (value);
				}
			}
	}

	public T last {
		get {
			return end.value;
		}

		set {
			if (length > 0) {
				end.value = value;
			} else {
				append (value);
			}
		}
	}

	public Node <T> last_node {
	    get {
	        return end;
	    }
	}

    public LinkedList () {
        length = 0;
        start = null;
        end = null;
    }

    public LinkedList.with_values (owned T value1, ...) {
        var node1 = new Node <T> (value1);
        start = (owned) node1;
        length = 1;

        var l = va_list ();
        T value = null;
        Node <T> node = null;
        unowned Node <T> last_node = start;

        while ( (value = l.arg ()) != null) {
            node = new Node <T> (value);
            last_node.next = (owned) node;
            last_node = last_node.next;
            length ++;
        }

        end = last_node;
    }

    public void append (T value) {
		#if PROFILE_LINKED_LIST
		append_info.start ();
		#endif

		var node = new Node <T> (value);

        if (length == 0) {
            end = node;
            start = (owned) node;
        } else {
			unowned var tmp = end;
			end = node;
			tmp.next = (owned) node;
        }

        length ++;

		#if PROFILE_LINKED_LIST
		append_info.end ();
		#endif

    }

    public void insert (T value, int index) requires (index > -1 && index <= length) {
        #if PROFILE_LINKED_LIST
		insert_info.start ();
		#endif
        var new_node = new Node <T> (value);

        if (index == 0) {
            new_node.next = (owned) start;
            start = (owned) new_node;

            if (length == 0) {
                end = new_node;
            }
        }

        if (index == length && index > 0) {
            end.next = (owned) new_node;
            end = new_node;
        }

        if (index != 0 && index != length) {
            unowned Node <T> node = start;

            while (index -- > 1) {
                node = node.next;
            }

            new_node.next = (owned) node.next;
            node.next = (owned) new_node;
        }


        length ++;
        #if PROFILE_LINKED_LIST
		insert_info.end ();
		#endif
    }

    public void insert_sorted (T value, SortingFunction sorting_function) {
		#if PROFILE_LINKED_LIST
		insert_sorted_info.start ();
		#endif
        Node <T> new_node = new Node <T> (value);

        if (length == 0) {
            start = (owned) new_node;
            end = new_node;
        } else {
            unowned Node <T> node = start;
            unowned Node <T> last_node = null;
            int i = 0;

            while (node != null && sorting_function (value, node.value)) {
                last_node = node;
                i ++;
                node = node.next;
            }

            if (i == 0) {
                new_node.next = (owned) start;
                start = (owned) new_node;
            } else if (i == length) {
                end = new_node;
                last_node.next = (owned) new_node;
            } else {
                new_node.next = (owned) last_node.next;
                last_node.next = (owned) new_node;
            }
        }

        length ++;
		#if PROFILE_LINKED_LIST
		insert_sorted_info.end ();
		#endif
    }

    public void remove (int index) requires (index > -1 && index < length) {

		#if PROFILE_LINKED_LIST
		remove_info.start ();
		#endif

        if (index == 0) {
            start = (owned) start.next;
        } else {
            unowned var node = start;
            unowned Node <T> last_node = null;
            var change_end = index == length - 1;

            while (index -- > 0) {
                last_node = node;
                node = node.next;
            }

            last_node.next = (owned) node.next;

            if (change_end) {
                end = last_node;
            }
        }

        length --;

        #if PROFILE_LINKED_LIST
		remove_info.end ();
		#endif
    }

    public bool remove_where (CompareFunction fun) requires (length > 0) {

        unowned Node <T> node = start;
        unowned Node <T> previous_node = null;

        while (node != null) {
            if (fun (node.value)) {

                if (previous_node == null) {
                    start = (owned) node.next;

                    if (length == 1) {
                        end = null;
                    }
                } else if (node.next == null) {
                    end = previous_node;
                    previous_node.next = null;
                } else {
                    previous_node.next = (owned) node.next;
                }

                length --;
                return true;
            }

        previous_node = node;
        node = node.next;
    }

        return false;
    }

    public void remove_next_node (unowned Node <T> node) requires (node.next != null) {
        #if PROFILE_LINKED_LIST
		remove_next_node_info.start ();
		#endif

		node.next = (owned) node.next.next;

		if (node.next == null)
		    end = node;

		length --;

		#if PROFILE_LINKED_LIST
		remove_next_node_info.end ();
		#endif
    }

    public void add_next_node (unowned Node <T> node, T value) {

        var new_node = new Node <T> (value);
        new_node.next = (owned) node.next;

        node.next = (owned) new_node;
        length ++;
    }

    public LinkedList <T> copy () {
        var copy = new LinkedList <T> ();
        unowned var node = start;

        while (node != null) {
            copy.append (node.value);
            node = node.next;
        }
        return copy;
    }

    public void clear () {
        length = 0;
        start = null;
        end = null;
    }

    public T @get (int index) requires (index < length && index > -1) {
        #if PROFILE_LINKED_LIST
		get_info.start ();
		#endif

        unowned Node <T> node = start;

        while (index -- > 0) {
            node = node.next;
        }
        #if PROFILE_LINKED_LIST
		get_info.end ();
		#endif
        return node.value;
    }

    public unowned Node <T> get_node (int index) {
        return _get_node (index);
    }

    public void @set (int index, T value) requires (index < length && index > -1) {
        #if PROFILE_LINKED_LIST
		set_info.start ();
		#endif

        unowned Node <T> node = start;

        while (index -- > 0) {
            node = node.next;
        }

        node.value = value;
        #if PROFILE_LINKED_LIST
		set_info.end ();
		#endif
    }

    public void each (Each fun) {
        unowned var node = start;
        bool proceed = true;

        while (node != null && proceed) {
            fun (node.value, ref proceed);
            node = node.next;
        }
    }

    public void each_i (EachI fun) {
        unowned var node = start;
        bool proceed = true;
        var i = 0;

        while (node != null && proceed) {
            fun (node.value, i, ref proceed);
            node = node.next;
            i ++;
        }
    }

	public void each_node (EachNode fun) {
        unowned var node = start;
        bool proceed = true;

        while (node != null && proceed) {
            fun (node, ref proceed);
            node = node.next;
        }
    }


    public void each_node_i (EachNodeI fun) {
        unowned var node = start;
        bool proceed = true;
        var i = 0;

        while (node != null && proceed) {
            fun (node, i, ref proceed);
            node = node.next;
            i ++;
        }
    }

    public Iterator <T> iterator () {
        return new Iterator <T> (start, length);
    }

    private inline unowned Node <T> _get_node (int index) requires (index > -1 && index < length) {

        unowned Node <T> node = start;

        while (index -- > 0) {
            node = node.next;
        }

        return node;
    }

    public unowned Node <T> find_node (CompareFunction fun) {
        unowned Node <T> node = start;

        while (node != null) {
            if (fun (node.value))
                return node;

            node = node.next;
        }

        return null;
    }

	[Compact]
    public class Node <T> {
        public Node <T> ? next;
        public T value;

        public Node (owned T value) {
            this.value = value;
            next = null;
            #if PROFILE_LINKED_LIST_LINKED_LIST
            print ("### creating Node (%p)) ###\n", this);
            #endif
        }

        ~Node () {
            #if PROFILE_LINKED_LIST_LINKED_LIST
            print ("### deleting Node (%p) ###\n", this);
            #endif
        }

    }


    public class Iterator <T> {
        private unowned Node <T> current_node;
        private int length;
        private int i = 0;

        public Iterator (Node <T>? start_node, int length) {
            current_node = start_node;
            this.length = length;
        }

        public T get () {
            i ++;
            var value = current_node.value;
            current_node = current_node.next;
            return value;
        }

        public bool next () {
            return i < length;
        }

    }

}

