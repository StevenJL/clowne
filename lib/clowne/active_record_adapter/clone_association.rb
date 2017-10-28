module Clowne
  module ActiveRecordAdapter
    # o.public_send(:order_items).instance_exec({id: 1}, &Proc.new { |params| where(id: params[:id]) })
    module ReflectionHelper
      def find_reflection(source, record, declaration)
        reflections = record.class.reflections
        association = declaration.name
        reflection = reflections[association.to_s]
        [association, reflection]
      end
    end

    class CloneAssociation
      extend ReflectionHelper

      def self.call(source, record, declaration)
        _, reflection = find_reflection(source, record, declaration)
        if reflection.is_a?(::ActiveRecord::Reflection::ThroughReflection)
          record
        elsif reflection.is_a?(::ActiveRecord::Reflection::HasOneReflection)
          CloneHasOneAssociation.call(source, record, declaration)
        elsif reflection.is_a?(::ActiveRecord::Reflection::HasManyReflection)
          CloneHasManyAssociation.call(source, record, declaration)
        elsif reflection.is_a?(::ActiveRecord::Reflection::HasAndBelongsToManyReflection)
          CloneHasAndBelongsToManyAssociation.call(source, record, declaration)
        else
          warn("Reflection #{reflection.class.name} does not support")
          record
        end
      end
    end

    class CloneHasOneAssociation
      extend ReflectionHelper

      def self.call(source, record, declaration)
        association, reflection = find_reflection(source, record, declaration)

        child = source.__send__(association)
        return record unless child
        child_clone = child.dup # TODO: use cloner!
        child_clone[:"#{reflection.foreign_key}"] = nil # TODO: use nullify ?
        record.__send__(:"#{association}=", child_clone)

        record
      end
    end

    class CloneHasManyAssociation
      extend ReflectionHelper

      def self.call(source, record, declaration)
        association, reflection = find_reflection(source, record, declaration)

        source.__send__(association).each do |child|
          child_clone = child.dup # TODO: use cloner!
          child_clone[:"#{reflection.foreign_key}"] = nil # TODO: use nullify ?
          record.__send__(association) << child_clone
        end

        record
      end
    end

    class CloneHasAndBelongsToManyAssociation
      extend ReflectionHelper

      def self.call(source, record, declaration)
        association, _ = find_reflection(source, record, declaration)

        source.__send__(association).each do |child|
          child_clone = child.dup # TODO: use cloner!
          record.__send__(association) << child_clone
        end

        record
      end
    end
  end
end
