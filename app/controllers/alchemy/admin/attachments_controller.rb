module Alchemy
  module Admin
    class AttachmentsController < ResourcesController
      helper 'alchemy/admin/tags'

      def index
        @query = Attachment.ransack(params[:q])
        @attachments = @query.result

        if params[:only].present?
          @attachments = @attachments.where("file_mime_type LIKE '%#{params[:only]}%'")
        end
        if params[:except].present?
          @attachments = @attachments.where("file_mime_type NOT LIKE '%#{params[:except]}%'")
        end
        if params[:tagged_with].present?
          @attachments = @attachments.tagged_with(params[:tagged_with])
        end

        @attachments = @attachments
          .page(params[:page] || 1)
          .per(15)

        @options = options_from_params
        if in_overlay?
          archive_overlay
        end
      end

      # The resources controller renders the edit form as default for show actions.
      def show
        render :show
      end

      def new
        @attachment = Attachment.new
        if in_overlay?
          set_instance_variables
        end
      end

      def create
        @attachment = Attachment.new(attachment_attributes)
        if @attachment.save
          if in_overlay?
            set_instance_variables
          end
          message = Alchemy.t('File uploaded succesfully', name: @attachment.name)
          render json: {files: [@attachment.to_jq_upload], growl_message: message}, status: :created
        else
          message = Alchemy.t('File upload error', error: @attachment.errors[:file].join)
          render json: {files: [@attachment.to_jq_upload], growl_message: message}, status: :unprocessable_entity
        end
      end

      def update
        @attachment.update_attributes(attachment_attributes)
        render_errors_or_redirect(
          @attachment,
          admin_attachments_path(
            per_page: params[:per_page],
            page: params[:page],
            q: params[:q]
          ),
          Alchemy.t("File successfully updated")
        )
      end

      def destroy
        name = @attachment.name
        @attachment.destroy
        @url = admin_attachments_url(
          per_page: params[:per_page],
          page: params[:page],
          q: params[:q]
        )
        flash[:notice] = Alchemy.t('File deleted successfully', name: name)
      end

      def download
        @attachment = Attachment.find(params[:id])
        send_file @attachment.file.path, {
          filename: @attachment.file_name,
          type: @attachment.file_mime_type
        }
      end

      private

      def in_overlay?
        params[:content_id].present?
      end

      def archive_overlay
        @content = Content.find_by(id: params[:content_id])
        @options = options_from_params
        respond_to do |format|
          format.html { render partial: 'archive_overlay' }
          format.js   { render action:  'archive_overlay' }
        end
      end

      def attachment_attributes
        params.require(:attachment).permit(:file, :name, :file_name, :tag_list)
      end

      def set_instance_variables
        @while_assigning = true
        @content = Content.find_by(id: params[:content_id])
        @swap = params[:swap]
        @options = options_from_params
      end
    end
  end
end
