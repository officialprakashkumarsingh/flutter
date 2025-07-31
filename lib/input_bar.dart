import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'file_attachment_service.dart';
import 'file_attachment_widget.dart';

/* ----------------------------------------------------------
   INPUT BAR – Clean Design with Unified Attachment Button
---------------------------------------------------------- */
class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.awaitingReply,
    required this.isEditing,
    required this.onCancelEdit,
    required this.onUnifiedAttachment,  // Combined image + file upload
    required this.attachedFiles,
    required this.onClearFile,
    required this.isImageGenerationMode,
    required this.selectedImageModel,
    required this.availableImageModels,
    required this.onImageModelChanged,
    required this.onCancelImageGeneration,
    required this.isGeneratingImage,
    required this.followUpMode,
    required this.onToggleFollowUp,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool awaitingReply;
  final bool isEditing;
  final VoidCallback onCancelEdit;
  final VoidCallback onUnifiedAttachment;  // Unified attachment function
  final List<FileAttachment> attachedFiles;
  final Function(String) onClearFile;
  final bool isImageGenerationMode;
  final String selectedImageModel;
  final List<String> availableImageModels;
  final Function(String) onImageModelChanged;
  final VoidCallback onCancelImageGeneration;
  final bool isGeneratingImage;
  final bool followUpMode;
  final VoidCallback onToggleFollowUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F3F0), // Main theme background
      ),
      child: Column(
        children: [
          // Edit mode indicator
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF000000).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFF000000), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Editing message...", 
                      style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCancelEdit();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

          // Image generation mode indicator
          if (isImageGenerationMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3748).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2D3748).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.wandMagic, color: Color(0xFF2D3748), size: 16),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Image Generation Mode", 
                      style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCancelImageGeneration();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

          // Model selection chips for image generation
          if (isImageGenerationMode)
            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
              child: Row(
                children: [
                  const Text(
                    'Model: ',
                    style: TextStyle(
                      color: Color(0xFF2D3748),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...availableImageModels.map((model) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onImageModelChanged(model);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedImageModel == model 
                              ? const Color(0xFF2D3748) 
                              : const Color(0xFF2D3748).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2D3748).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          model.toUpperCase(),
                          style: TextStyle(
                            color: selectedImageModel == model 
                                ? Colors.white 
                                : const Color(0xFF2D3748),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                  
                  const Spacer(),
                  
                  // Follow-up toggle for image generation model
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onToggleFollowUp();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: followUpMode 
                            ? const Color(0xFF2D3748) 
                            : const Color(0xFF2D3748).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2D3748).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.link,
                            size: 10,
                            color: followUpMode 
                                ? Colors.white 
                                : const Color(0xFF2D3748),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Follow-up',
                            style: TextStyle(
                              color: followUpMode 
                                  ? Colors.white 
                                  : const Color(0xFF2D3748),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // File attachments display
          if (attachedFiles.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SimpleFileAttachmentWidget(
                attachments: attachedFiles,
                onRemove: (attachment) => onClearFile(attachment.id),
              ),
            ),
          
          // Main input container
          Container(
            margin: EdgeInsets.fromLTRB(20, isEditing ? 0 : 16, 20, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white, // White input background
              borderRadius: BorderRadius.circular(24), // Fully rounded border
              border: Border.all(
                color: const Color(0xFFEAE9E5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // UNIFIED ATTACHMENT BUTTON (combines image + file)
                if (!awaitingReply && !isImageGenerationMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onUnifiedAttachment();  // Single unified attachment function
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: attachedFiles.isNotEmpty 
                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                              : const Color(0xFFA3A3A3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.paperclip,  // Universal attachment icon
                          color: attachedFiles.isNotEmpty 
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFA3A3A3),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                
                // Text input field
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !awaitingReply,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: const Color(0xFF000000),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 16,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: awaitingReply 
                          ? 'AhamAI is responding...' 
                          : isGeneratingImage
                              ? 'Generating image...'
                              : isImageGenerationMode
                                  ? 'Enter your image prompt...'
                              : attachedFiles.isNotEmpty
                                  ? 'Attachments ready - Ask about them...'
                                  : 'Message AhamAI',
                      hintStyle: const TextStyle(
                        color: Color(0xFFA3A3A3),
                        fontSize: 16,
                        height: 1.4,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                
                // Send/Stop button
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 6),
                  child: GestureDetector(
                    onTap: awaitingReply ? onStop : onSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: awaitingReply 
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: awaitingReply 
                          ? const Icon(Icons.stop_circle, color: Colors.red, size: 18)
                          : isGeneratingImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  isImageGenerationMode 
                                      ? FontAwesomeIcons.wandMagic 
                                      : Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}