function Project_Pudage_Akshay(fn)
    close all;
    clc;

    addpath('/Dataset');
    addpath('/Templates');
    %Read the input image
    fprintf('Reading image...\n')
    im = imread(fn);

    %Rotate the portrait image to landscape
    if size(im,1) > size(im,2)
        im = imrotate(im,90);
    end

    %Save a copy of original iage
    og = im;

    imshow(og)
    %% LOAD TEMPLATES
    %Read in the suit templates
    fprintf('Reading templates...\n')
    spades_og = imread('Templates\Suits\spades.jpg');
    hearts_og = imread('Templates\Suits\hearts.jpg');
    diamonds_og = imread('Templates\Suits\diamonds.jpg');
    clubs_og = imread('Templates\Suits\clubs.jpg');

    %Read in the rank templates
    rank_A_og = imread('Templates\Ranks\A.jpg');
    rank_2_og = imread('Templates\Ranks\2.jpg');
    rank_3_og = imread('Templates\Ranks\3.jpg');
    rank_4_og = imread('Templates\Ranks\4.jpg');
    rank_5_og = imread('Templates\Ranks\5.jpg');
    rank_6_og = imread('Templates\Ranks\6.jpg');
    rank_7_og = imread('Templates\Ranks\7.jpg');
    rank_8_og = imread('Templates\Ranks\8.jpg');
    rank_9_og = imread('Templates\Ranks\9.jpg');
    rank_10_og = imread('Templates\Ranks\10.jpg');
    rank_J_og = imread('Templates\Ranks\J.jpg');
    rank_Q_og = imread('Templates\Ranks\Q.jpg');
    rank_K_og = imread('Templates\Ranks\K.jpg');

    number_of_cards = 0;

    %Defining names of each suit and rank in a specific order for output
    shape_names = {'HEARTS','DIAMONDS','SPADES','CLUBS'};
    rank_names = {'A','2','3','4','5','6','7','8','9','10','J','Q','K'};

    %Adding the templates of suit and rank in cell arrays for ease of
    %processing
    suits = {hearts_og,diamonds_og,spades_og,clubs_og};
    ranks = {rank_A_og,rank_2_og,rank_3_og,rank_4_og,rank_5_og,rank_6_og,rank_7_og,rank_8_og,rank_9_og,rank_10_og,rank_J_og,rank_Q_og,rank_K_og};

    fprintf('Processing templates...\n')
    %Preprocess each of the suit templates
    for i=1:length(suits)
        suits{i} = process_template(suits{i});
    end

    %Preprocess each of the rank templates
    for i=1:length(ranks)
        ranks{i} = process_template(ranks{i});
    end


    %% PRE-PROCESSING

    %Histogram Equailization
    im = imadjust(im(:,:,3));

    %Otsu's Method
    threshold = graythresh(im);

    %Convert the image to binary
    im = im2bw(im,threshold);

    %Noise Removal
    gaussian_filter = fspecial('gauss',2,1);
    im = imfilter(im,gaussian_filter,'same','repl');
    im = medfilt2(im);

    %Segment the binary image
    [separations,n_labels] = bwlabel(im);

    fprintf('Detecting cards...\n\n')
    %% PROCESS EACH CARD
     for ii = 1:n_labels
            %Find a logical image corresponding to the separation.
            oneregion = (separations==ii);

            %Get the region properties
            polyXY = regionprops(oneregion,'ConvexHull','Area','Centroid','Orientation', 'BoundingBox');


           %If the area of convex hull is <=70000, it probably is not a playing card but
           %noise, so reject it.
           if (polyXY.Area <=70000)
               continue
           end

          %Crop the playing card out
          croppedImage = imcrop(im, polyXY.BoundingBox);

          % Compute orientation angle of the region
          angle = polyXY.Orientation;

          % Rotate image to vertical orientation. This handles the orientation
          % variations of playing cards in an image.
          uprightImage = imrotate(croppedImage, -angle+90);
          [rows, columns] = find(uprightImage);

          %Crop the playing card after rotating
          topRow = min(rows);
          bottomRow = max(rows);
          leftColumn = min(columns);
          rightColumn = max(columns);
          croppedImage_og = uprightImage(topRow:bottomRow, leftColumn:rightColumn);

          %Get the dimensions of the cropped image (playing card)
          fprintf('Card detected...\n')
          number_of_cards = number_of_cards + 1;
          [r,c] = size(croppedImage_og);

          %Define rotation angle for matching template with top left anf bottom
          %right region of playing card
          rotate_angle = {0,180};

          %Define predetermined template sizes to resize the original template.
          %This handles scale variations of cards.
          size_template = {1,0.7};

          %Variables for max correlation of suit and rank
          max_shape = 0;
          max_rank=0;

          fprintf('Identifying card...\n')

          % TEMPLATE MATCHING             

            for i=1:length(rotate_angle)
                croppedImage = imrotate(croppedImage_og,rotate_angle{i});
                %Get the ROI
                croppedImage = croppedImage(1:int16(r/2),1:int16(c/2));

                %Compute Correlation of suits of varying sizes with image

                for suits_counter=1:length(suits)
                    for q=1:length(size_template)
                        current_shape = imresize(suits{suits_counter},size_template{q});
                        shape_correlation_matrix = normxcorr2(current_shape,croppedImage);
                        shape_correlation = max(shape_correlation_matrix(:));

                         if shape_correlation > 0.9
                            shape = shape_names{suits_counter};
                            max_shape = shape_correlation;
                            break;
                         end
                    if (shape_correlation > max_shape)
                        max_shape = shape_correlation;
                        shape = shape_names{suits_counter};
                    end
                  end
                end

            %Compute Correlation of ranks of varying sizes with image

            for ranks_counter=1:length(ranks)

                for q=1:length(size_template)

                    current_rank = imresize(ranks{ranks_counter},size_template{q});
                    rank_correlation_matrix = normxcorr2(current_rank,croppedImage);
                    rank_correlation = max(rank_correlation_matrix(:));
                    if rank_correlation > 0.9
                        max_rank =  rank_correlation;
                        rank = rank_names{ranks_counter};
                        break;
                    end
                    if (rank_correlation > max_rank)
                        max_rank = rank_correlation;
                        rank = rank_names{ranks_counter};
                    end
                end
            end
            end

            fprintf('Card identification complete...\n\n')

            %Text formatting for fprintflaying the result
            current_title = sprintf(' %s of %s',rank,shape);

            %Get centroid co-ordinates of the region to fprintflay the output.
            position = [polyXY.Centroid(1) polyXY.Centroid(2)];

            %Add text to the image to fprintflay the card information.
            og = insertText(og,position,current_title,'FontSize',100,'BoxColor','green','BoxOpacity',0.9,'TextColor','blue','AnchorPoint','Center');
            imshow(og);
        end
     text_format = sprintf('Number of cards detected=%d\n',number_of_cards);
     fprintf(text_format);
 
end

function template=process_template(im)
    %Preprocess template
    template = 0;
    
    %Contrast Enhancement
    im = imadjust(im(:,:,3));
    
    %Find Otsu's Threshold
    threshold = graythresh(im);
    
    %Convert image to binary
    im = im2bw(im,threshold);
    template = im;
end