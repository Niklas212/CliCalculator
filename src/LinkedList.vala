
public class LinkedList <T> {

    public int length {get; private set;}
    private Node <T> ? start;
    private Node <T> ? end;

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

    public LinkedList () {
        length = 0;
        start = null;
        end = null;
    }

    public void append (T value) {
        var node = new Node <T> (value);

        if (length == 0) {
            start = end = node;
        } else {
            end.next = end = node;
        }

        length ++;
    }

    public void insert (T value, int index) requires (index > -1 && index <= length) {
        var new_node = new Node <T> (value);

        if (index == 0) {
            new_node.next = start;
            start = new_node;

            if (length == 0) {
                end = new_node;
            }
        }

        if (index == length && index > 0) {
            end = end.next = new_node;
        }

        if (index != 0 && index != length) {
            unowned Node <T> node = start;

            while (index -- > 1) {
                node = node.next;
            }

            new_node.next = node.next;
            node.next = new_node;
        }


        length ++;
    }

    public void insert_sorted (T value, SortingFunction sorting_function) {

        Node <T> new_node = new Node <T> (value);

        if (length == 0) {
            start = end = new_node;
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
                new_node.next = start;
                start = new_node;
            } else if (i == length) {
                last_node.next = new_node;
                end = new_node;
            } else {
                new_node.next = node;
                last_node.next = new_node;
            }
        }

        length ++;
    }

    public void remove (int index) requires (index > -1 && index < length) {

        if (index == 0) {
            start = start.next;
        } else {
            var node = start;
            unowned Node <T> last_node = null;
            var change_end = index == length - 1;

            while (index -- > 0) {
                last_node = node;
                node = node.next;
            }

            last_node.next = node.next;

            if (change_end) {
                end = last_node;
            }
        }

        length --;
    }

    public LinkedList <T> copy () {
        var copy = new LinkedList <T> ();
        var node = start;

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
        unowned Node <T> node = start;

        while (index -- > 0) {
            node = node.next;
        }

        return node.value;
    }

    public void @set (int index, T value) requires (index < length && index > -1) {
        unowned Node <T> node = start;

        while (index -- > 0) {
            node = node.next;
        }

        node.value = value;
    }

    public void each (Each fun) {
        var node = start;

        while (node != null) {
            fun (node.value);
            node = node.next;
        }
    }

    public void each_i (EachI fun) {
        var node = start;
        var i = 0;

        while (node != null) {
            fun (node.value, i);
            node = node.next;
            i ++;
        }
    }

    public Iterator <T> iterator () {
        return new Iterator <T> (start, length);
    }

    private inline unowned Node <T> get_node (int index) requires (index > -1 && index < length) {
        unowned Node <T> node = start;

        while (index -- > 0) {
            node = node.next;
        }

        return node;
    }

    public class Node <T> {
        public T value;
        public Node <T> ? next;

        public Node (T value) {
            this.value = value;
            next = null;
            #if DEBUG_LINKED_LIST
            print (@"### creating Node ($((uint)value)) ###\n");
            #endif
        }

        ~Node () {
            #if DEBUG_LINKED_LIST
            print (@"### deleting Node ($((uint)value)) ###\n");
            #endif
        }

    }

    public class Iterator <T> {
        private  Node <T> current_node;
        private int length;
        private int i = 0;

        // it is nullable to fix a runtime warning
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

    public delegate bool SortingFunction <T> (T a, T b);
    public delegate void Each <T> (T value);
    public delegate void EachI <T> (T value, int index);

}
