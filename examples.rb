# frozen_string_literal: true

Node = Struct.new(:value, :next)

node1 =  Node.new(0)
node2 =  Node.new(1)
node3 =  Node.new(2)
node4 =  Node.new(3)

node1.next = node2
node2.next = node3
node3.next = node4
node4.next = :null_pointer

puts node1