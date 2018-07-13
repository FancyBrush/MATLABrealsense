clear, clc;
target_folder = 'checker_imgs';
%target_folder = 'checker_imgs\white trouble';
%checker_imgs\pictures_with_wrong_points_over_them
%checker_imgs\pictures_with_wrong_points_over_them\specia_points_onBkmargins
addpath(target_folder);
[img_names, img2]  = save_file_names_in_folder(target_folder,'png');

% img_names = "check8.png";
% img2 = deblank(char(img_names));
%stores names of files with errors from try and catch, which were
failed_imgs = "";
failure = MException.empty(); %initializing exception array
% img_names = "check25.png";
% img2 = char(img_names);

j = 0;
for img_i=1:size(img_names,1)
    [checker_found, error] = ColorPatchDetectClean(deblank(img2(img_i,:)));
    if ~isempty(error) && checker_found %only records the error if checker was found
        failed_imgs(j+1,:) = img_names(img_i,:);
        failure(j + 1) = error; %exception returned by function, if there was one
        j = j + 1;
    end
end
if ~isempty(failure) %if there's an exception saved, builds table
     %with file name and related exception
     % syntax for access
         %fail_img_err_table.failed_imgs(i) : imgs file names
         %fail_img_err_table.Var1(i) : exceptions returned
    fail_img_err_table = table(failure',failed_imgs);
    save('fail_img_err_table.mat','fail_img_err_table');
end
close all
